defmodule GemWeb.FaultToleranceDemoLive do
  @moduledoc false
  use GemWeb, :live_view

  alias Gem.Demo.FaultTolerance.APIWorker
  alias Gem.Demo.FaultTolerance.CacheWorker
  alias Gem.Demo.FaultTolerance.DBWorker
  alias Gem.Demo.FaultTolerance.Supervisor
  alias Gem.Demo.Supervisor, as: DemoSupervisor

  @typep stop_reason :: :manual_stop | :strategy_change | :shutdown
  @typep event_type :: :system | :action | :error | :warning | :info

  @canvas_nodes [
    %{key: :supervisor, name: "Root Supervisor", x: 50, y: 25, color: "#e2a478"},
    %{key: :api, name: "API Worker", x: 18, y: 84, color: APIWorker.metadata().color},
    %{key: :db, name: "DB Worker", x: 50, y: 88, color: DBWorker.metadata().color},
    %{key: :cache, name: "Cache Worker", x: 82, y: 84, color: CacheWorker.metadata().color}
  ]

  @strategy_options [
    %{label: "One for One", value: "one_for_one", description: "Restarts the crashed process only."},
    %{label: "One for All", value: "one_for_all", description: "Restarts the whole tree when one crashes."},
    %{label: "Rest for One", value: "rest_for_one", description: "Restarts the crashed process and dependents."}
  ]

  @crash_options [
    %{label: "Runtime Error", value: "runtime", tone: :warning},
    %{label: "Timeout", value: "timeout", tone: :warning},
    %{label: "Normal Exit", value: "normal", tone: :muted},
    %{label: "Brutal Kill", value: "brutal_kill", tone: :danger}
  ]

  @max_events 32
  @restart_animation_ms 1100

  @impl true
  def mount(_params, _session, socket) do
    session_ref = "ft-" <> Integer.to_string(System.unique_integer([:positive]))
    control_data = %{"strategy" => "one_for_one", "crash_type" => "runtime"}

    socket =
      socket
      |> assign(:page_title, "Fault Tolerance & Supervision Demo")
      |> assign(:session_ref, session_ref)
      |> assign(:control_data, control_data)
      |> assign(:control_form, to_form(control_data, as: :controls))
      |> assign(:strategy, :one_for_one)
      |> assign(:crash_type, :runtime)
      |> assign(:system_running?, false)
      |> assign(:supervisor_pid, nil)
      |> assign(:worker_states, default_worker_states())
      |> assign(:monitors, %{})
      |> assign(:restart_timers, %{})
      |> assign(:event_counter, 0)
      |> assign(:event_order, [])
      |> assign(:stats, %{total_crashes: 0, total_restarts: 0, health: 100, uptime_ms: 0})
      |> assign(:system_started_at, nil)
      |> assign(:uptime_timer_ref, nil)
      |> assign(:strategy_description, strategy_description(:one_for_one))
      |> assign(:last_strategy_switch, nil)
      |> assign(:worker_order, [:db, :cache, :api])
      |> stream(:events, [])
      |> push_event_entry(:system, "Supervisor tree ready", detail: "Press start to bootstrap the demo.")

    {:ok, socket}
  end

  @impl true
  def handle_event("start_system", _params, socket) do
    case start_tree(socket) do
      {:ok, socket} -> {:noreply, socket}
      {:error, socket} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stop_system", _params, socket) do
    {:noreply, stop_system(socket, :manual_stop)}
  end

  @impl true
  def handle_event("select_strategy", %{"controls" => %{"strategy" => value}}, socket) do
    case parse_strategy(value) do
      {:ok, strategy} ->
        new_control_data = Map.put(socket.assigns.control_data, "strategy", value)

        socket =
          socket
          |> assign(:strategy, strategy)
          |> assign(:strategy_description, strategy_description(strategy))
          |> assign(:control_data, new_control_data)
          |> assign(:control_form, to_form(new_control_data, as: :controls))
          |> assign(:last_strategy_switch, DateTime.utc_now())

        socket =
          if socket.assigns.system_running? do
            socket
            |> push_event_entry(:system, "Switching strategy", detail: strategy_name(strategy))
            |> restart_tree_with_strategy(strategy)
          else
            socket
          end

        {:noreply, socket}

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_crash", %{"controls" => %{"crash_type" => value}}, socket) do
    case parse_crash(value) do
      {:ok, crash_type} ->
        control_data = Map.put(socket.assigns.control_data, "crash_type", value)

        {:noreply,
         socket
         |> assign(:crash_type, crash_type)
         |> assign(:control_data, control_data)
         |> assign(:control_form, to_form(control_data, as: :controls))}

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("crash_worker", %{"worker" => worker_key}, socket) do
    if socket.assigns.system_running? do
      key = String.to_existing_atom(worker_key)
      crash_type = socket.assigns.crash_type

      case socket.assigns.worker_states[key] do
        %{pid: nil} ->
          {:noreply,
           push_event_entry(socket, :warning, "#{human_worker(key)} is offline", detail: "Start the system first.")}

        %{pid: pid} ->
          GenServer.cast(pid, {:crash, crash_type})

          socket =
            socket
            |> update_worker_state(key, fn state ->
              state
              |> Map.put(:status, :pending)
              |> Map.put(:pending_reason, crash_type)
            end)
            |> push_event_entry(:action, "Triggering #{human_crash(crash_type)}", detail: human_worker(key))

          {:noreply, socket}
      end
    else
      {:noreply, push_event_entry(socket, :warning, "System is offline", detail: "Start the tree to trigger crashes.")}
    end
  rescue
    ArgumentError ->
      {:noreply, socket}
  end

  @impl true
  def handle_info({:worker_started, session_ref, metadata, pid}, socket) do
    if session_ref == socket.assigns.session_ref do
      {:noreply, worker_started(socket, metadata, pid)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, socket) do
    {key, monitors} = pop_monitor_by_ref(socket.assigns.monitors, ref)

    socket =
      if key do
        socket
        |> assign(:monitors, monitors)
        |> cancel_restart_timer(key)
        |> handle_worker_down(key, pid, reason)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:transition_running, key}, socket) do
    # Drop and cancel any pending timer for this key
    {ref, timers} = Map.pop(socket.assigns.restart_timers, key)
    if ref, do: Process.cancel_timer(ref)

    socket =
      update_worker_state(%{socket | assigns: %{socket.assigns | restart_timers: timers}}, key, fn state ->
        # Only set to running if the worker is alive or was recently started
        case state.status do
          :restarting -> Map.put(state, :status, :running)
          _ -> state
        end
      end)

    {:noreply, socket}
  end

  def handle_info(:uptime_tick, %{assigns: %{system_running?: true}} = socket) do
    uptime_ms = uptime_now(socket.assigns.system_started_at)
    stats = %{socket.assigns.stats | uptime_ms: uptime_ms}
    {:noreply, assign(socket, :stats, stats)}
  end

  def handle_info(:uptime_tick, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    stop_system(socket, :shutdown)
    :ok
  end

  ## Lifecycle helpers

  defp start_tree(%{assigns: %{system_running?: true}} = socket), do: {:ok, socket}

  defp start_tree(socket) do
    child_spec = %{
      id: {:fault_tolerance_demo, socket.assigns.session_ref},
      start:
        {Supervisor, :start_link,
         [
           [
             session_pid: self(),
             session_ref: socket.assigns.session_ref,
             strategy: socket.assigns.strategy
           ]
         ]},
      restart: :temporary,
      shutdown: 5_000,
      type: :supervisor
    }

    case DemoSupervisor.start_tree(child_spec) do
      {:ok, pid} ->
        socket =
          socket
          |> assign(:system_running?, true)
          |> assign(:supervisor_pid, pid)
          |> assign(:system_started_at, System.monotonic_time(:millisecond))
          |> assign(:stats, %{socket.assigns.stats | uptime_ms: 0})
          |> mark_workers_booting()
          |> start_uptime_timer()
          |> push_event_entry(:system, "System online", detail: human_strategy(socket.assigns.strategy))

        {:ok, socket}

      {:error, reason} ->
        socket = push_event_entry(socket, :error, "Unable to start supervisor", detail: inspect(reason))
        {:error, socket}
    end
  end

  defp restart_tree_with_strategy(socket, strategy) do
    socket = stop_system(socket, :strategy_change)
    socket = assign(socket, :strategy, strategy)

    case start_tree(socket) do
      {:ok, socket} -> socket
      {:error, socket} -> socket
    end
  end

  defp stop_system(socket, reason) do
    running? = socket.assigns.system_running?

    if running? and socket.assigns.supervisor_pid do
      DemoSupervisor.stop_tree(socket.assigns.supervisor_pid)
    end

    socket = socket |> cancel_uptime_timer() |> cancel_all_restart_timers()

    socket =
      socket
      |> assign(:system_running?, false)
      |> assign(:supervisor_pid, nil)
      |> assign(:system_started_at, nil)
      |> assign(:worker_states, default_worker_states())
      |> assign(:monitors, %{})
      |> assign(:stats, %{socket.assigns.stats | uptime_ms: 0})

    if running? do
      push_event_entry(socket, :system, stop_message(reason), detail: "All workers offline.")
    else
      socket
    end
  end

  @spec stop_message(stop_reason()) :: String.t()
  defp stop_message(:manual_stop), do: "System powered down"
  defp stop_message(:strategy_change), do: "Restarting with new strategy"
  defp stop_message(:shutdown), do: "Demo session terminated"

  ## Worker state helpers

  defp default_worker_states do
    Map.new(workers_metadata(), fn {key, spec} ->
      {key,
       Map.merge(spec, %{
         status: :offline,
         pid: nil,
         monitor_ref: nil,
         restarts: 0,
         crashes: 0,
         last_exit_reason: nil,
         last_exit_at: nil,
         last_start_at: nil,
         pending_reason: nil,
         pending_restart: false
       })}
    end)
  end

  defp workers_metadata do
    %{
      db: Map.put(DBWorker.metadata(), :position, %{x: 22, y: 64}),
      cache: Map.put(CacheWorker.metadata(), :position, %{x: 50, y: 69}),
      api: Map.put(APIWorker.metadata(), :position, %{x: 78, y: 64})
    }
  end

  defp mark_workers_booting(socket) do
    update_worker_states(socket, fn state ->
      state
      |> Map.put(:status, :booting)
      |> Map.put(:pending_reason, nil)
    end)
  end

  defp update_worker_states(socket, fun) do
    updated = Map.new(socket.assigns.worker_states, fn {k, v} -> {k, fun.(v)} end)
    assign(socket, :worker_states, updated)
  end

  defp update_worker_state(socket, key, fun) do
    worker_states = socket.assigns.worker_states
    updated_state = fun.(Map.fetch!(worker_states, key))
    assign(socket, :worker_states, Map.put(worker_states, key, updated_state))
  end

  defp worker_started(socket, metadata, pid) do
    key = metadata.key
    prev_state = socket.assigns.worker_states[key]

    was_restart? = prev_state.pending_restart || not is_nil(prev_state.pid)
    restarts_delta = if was_restart?, do: 1, else: 0

    {monitors, prev_ref} = pop_monitor_by_key(socket.assigns.monitors, key)
    if prev_ref, do: Process.demonitor(prev_ref, [:flush])
    ref = Process.monitor(pid)

    {worker_states, socket} =
      if was_restart? do
        # Keep visible "restarting" badge for a short period after boot
        ws =
          Map.update!(socket.assigns.worker_states, key, fn state ->
            state
            |> Map.put(:pid, pid)
            |> Map.put(:monitor_ref, ref)
            |> Map.put(:status, :restarting)
            |> Map.put(:pending_reason, nil)
            |> Map.put(:pending_restart, false)
            |> Map.put(:last_start_at, DateTime.utc_now())
            |> Map.update(:restarts, restarts_delta, &(&1 + restarts_delta))
          end)

        socket =
          socket
          |> cancel_restart_timer(key)
          |> put_restart_timer(key, Process.send_after(self(), {:transition_running, key}, @restart_animation_ms))

        {ws, socket}
      else
        ws =
          Map.update!(socket.assigns.worker_states, key, fn state ->
            state
            |> Map.put(:pid, pid)
            |> Map.put(:monitor_ref, ref)
            |> Map.put(:status, :running)
            |> Map.put(:pending_reason, nil)
            |> Map.put(:pending_restart, false)
            |> Map.put(:last_start_at, DateTime.utc_now())
            |> Map.update(:restarts, restarts_delta, &(&1 + restarts_delta))
          end)

        {ws, socket}
      end

    stats =
      update_health(%{
        socket.assigns.stats
        | total_restarts: socket.assigns.stats.total_restarts + restarts_delta
      })

    socket =
      socket
      |> assign(:monitors, Map.put(monitors, ref, key))
      |> assign(:worker_states, worker_states)
      |> assign(:stats, stats)

    if restarts_delta > 0 do
      push_event_entry(socket, :info, "#{metadata.name} restarted", detail: human_strategy(socket.assigns.strategy))
    else
      socket
    end
  end

  defp handle_worker_down(socket, key, _pid, reason) do
    worker = socket.assigns.worker_states[key]
    restart_policy = worker.restart
    expected_restart? = expects_restart?(restart_policy, reason)
    crash? = crash_reason?(reason)

    worker_states =
      Map.update!(socket.assigns.worker_states, key, fn state ->
        state
        |> Map.put(:pid, nil)
        |> Map.put(:monitor_ref, nil)
        |> Map.put(:last_exit_reason, reason)
        |> Map.put(:last_exit_at, DateTime.utc_now())
        |> Map.update(:crashes, if(crash?, do: 1, else: 0), fn val ->
          if crash?, do: val + 1, else: val
        end)
        |> Map.put(:status, worker_status_after_exit(expected_restart?, crash?))
        |> Map.put(:pending_restart, expected_restart?)
      end)

    stats =
      socket.assigns.stats
      |> maybe_increment_crashes(crash?)
      |> update_health()

    socket = assign(socket, worker_states: worker_states, stats: stats)

    socket =
      if crash? do
        :telemetry.execute([:demo, :worker, :exit], %{count: 1}, %{worker: key, reason: reason})
        push_event_entry(socket, :warning, "#{human_worker(key)} crashed", detail: format_reason(reason))
      else
        push_event_entry(socket, :info, "#{human_worker(key)} stopped", detail: format_reason(reason))
      end

    if expected_restart? and socket.assigns.system_running? do
      push_event_entry(socket, :system, "Supervisor restarting", detail: human_worker(key))
    else
      socket
    end
  end

  defp worker_status_after_exit(true, _crash?), do: :restarting
  defp worker_status_after_exit(false, true), do: :offline
  defp worker_status_after_exit(false, false), do: :offline

  defp maybe_increment_crashes(stats, true), do: %{stats | total_crashes: stats.total_crashes + 1}
  defp maybe_increment_crashes(stats, false), do: stats

  defp crash_reason?(:normal), do: false
  defp crash_reason?({:shutdown, _}), do: false
  defp crash_reason?(:shutdown), do: false
  defp crash_reason?(_), do: true

  defp expects_restart?(:permanent, _reason), do: true
  defp expects_restart?(:temporary, _reason), do: false

  defp expects_restart?(:transient, reason) do
    crash_reason?(reason)
  end

  ## Event stream helpers

  defp push_event_entry(socket, type, message, opts) do
    detail = Keyword.get(opts, :detail)
    event_id = socket.assigns.event_counter + 1

    entry = %{
      id: "event-#{event_id}",
      type: type,
      icon: event_icon(type),
      accent: event_accent(type),
      message: message,
      detail: detail,
      timestamp: DateTime.utc_now()
    }

    socket =
      socket
      |> assign(:event_counter, event_id)
      |> assign(:event_order, [entry.id | socket.assigns.event_order])
      |> stream_insert(:events, entry, at: 0)

    trim_event_stream(socket)
  end

  defp trim_event_stream(socket) do
    order = socket.assigns.event_order

    if length(order) > @max_events do
      {remove_id, remaining} = List.pop_at(order, -1)

      socket
      |> assign(:event_order, remaining)
      |> stream_delete(:events, %{id: remove_id})
    else
      socket
    end
  end

  @spec event_icon(event_type()) :: String.t()
  defp event_icon(:system), do: "hero-bolt"
  defp event_icon(:action), do: "hero-play"
  defp event_icon(:error), do: "hero-x-circle"
  defp event_icon(:warning), do: "hero-exclamation-triangle"
  defp event_icon(:info), do: "hero-information-circle"

  @spec event_accent(event_type()) :: String.t()
  defp event_accent(:system), do: "from-amber-400/80 to-orange-500/60"
  defp event_accent(:action), do: "from-blue-400/80 to-cyan-500/60"
  defp event_accent(:error), do: "from-red-500/80 to-pink-500/70"
  defp event_accent(:warning), do: "from-amber-400/80 to-red-400/60"
  defp event_accent(:info), do: "from-emerald-400/80 to-teal-500/70"

  defp parse_strategy(value) do
    case value do
      "one_for_one" -> {:ok, :one_for_one}
      "one_for_all" -> {:ok, :one_for_all}
      "rest_for_one" -> {:ok, :rest_for_one}
      _ -> :error
    end
  end

  defp parse_crash(value) do
    case value do
      "normal" -> {:ok, :normal}
      "runtime" -> {:ok, :runtime}
      "timeout" -> {:ok, :timeout}
      "brutal_kill" -> {:ok, :brutal_kill}
      _ -> :error
    end
  end

  defp human_strategy(:one_for_one), do: "Restarting only the crashed worker."
  defp human_strategy(:one_for_all), do: "Restarting the entire tree when one worker fails."
  defp human_strategy(:rest_for_one), do: "Restarting the crashed worker and those started after it."

  defp human_crash(:normal), do: "normal exit"
  defp human_crash(:runtime), do: "runtime failure"
  defp human_crash(:timeout), do: "timeout"
  defp human_crash(:brutal_kill), do: "brutal kill"

  defp human_worker(:db), do: DBWorker.metadata().name
  defp human_worker(:cache), do: CacheWorker.metadata().name
  defp human_worker(:api), do: APIWorker.metadata().name

  defp policy_label(restart) when is_atom(restart) do
    restart
    |> Atom.to_string()
    |> String.trim_leading(":")
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp policy_label(restart) when is_binary(restart), do: restart

  defp update_health(stats) do
    crash_penalty = stats.total_crashes * 6
    boost = min(stats.total_restarts * 2, 20)
    health = max(5, 100 - crash_penalty + boost)
    Map.put(stats, :health, min(100, health))
  end

  defp pop_monitor_by_ref(monitors, ref) do
    case Map.pop(monitors, ref) do
      {nil, _} -> {nil, monitors}
      {key, rest} -> {key, rest}
    end
  end

  defp pop_monitor_by_key(monitors, key) do
    case Enum.find(monitors, fn {_ref, worker_key} -> worker_key == key end) do
      {ref, ^key} -> {Map.delete(monitors, ref), ref}
      nil -> {monitors, nil}
    end
  end

  defp start_uptime_timer(socket) do
    socket = cancel_uptime_timer(socket)
    {:ok, ref} = :timer.send_interval(1_000, :uptime_tick)
    assign(socket, :uptime_timer_ref, ref)
  end

  defp cancel_uptime_timer(socket) do
    case socket.assigns.uptime_timer_ref do
      nil ->
        socket

      ref ->
        :timer.cancel(ref)
        assign(socket, :uptime_timer_ref, nil)
    end
  end

  defp cancel_all_restart_timers(socket) do
    Enum.each(Map.values(socket.assigns.restart_timers), fn ref -> Process.cancel_timer(ref) end)
    assign(socket, :restart_timers, %{})
  end

  defp cancel_restart_timer(socket, key) do
    case Map.pop(socket.assigns.restart_timers, key) do
      {nil, timers} ->
        assign(socket, :restart_timers, timers)

      {ref, timers} ->
        Process.cancel_timer(ref)
        assign(socket, :restart_timers, timers)
    end
  end

  defp put_restart_timer(socket, key, ref) do
    assign(socket, :restart_timers, Map.put(socket.assigns.restart_timers, key, ref))
  end

  defp uptime_now(nil), do: 0

  defp uptime_now(started_at_ms) do
    System.monotonic_time(:millisecond) - started_at_ms
  end

  # Compact, one-line last-exit classifier for the sidebar.
  # Maps complex exit terms to a small set of atom-like labels:
  # :runtime_error | :timeout | :kill | :normal | :unknown
  defp compact_reason({%{__struct__: mod} = _exception, _stack}) when is_atom(mod) do
    ":runtime_error"
  end

  defp compact_reason(%{__struct__: mod}) when is_atom(mod), do: ":runtime_error"

  defp compact_reason({:shutdown, _}), do: ":normal"
  defp compact_reason(:normal), do: ":normal"
  defp compact_reason(:shutdown), do: ":normal"
  defp compact_reason(:timeout), do: ":timeout"
  defp compact_reason(:kill), do: ":kill"
  defp compact_reason(:killed), do: ":kill"
  defp compact_reason(other) when is_atom(other), do: ":#{other}"
  defp compact_reason(_), do: ":unknown"

  defp format_reason({:shutdown, :one_for_all}), do: "Supervisor restart (one_for_all)"
  defp format_reason({:shutdown, :restart}), do: "Supervisor restart"
  defp format_reason({:shutdown, reason}), do: "Shutdown: #{inspect(reason)}"
  defp format_reason(:normal), do: "Normal exit"
  defp format_reason(:kill), do: "Killed"
  defp format_reason(:killed), do: "Killed"

  defp format_reason(%{__struct__: mod} = exception) do
    if function_exported?(mod, :exception, 1) do
      exception
      |> Exception.message()
      |> String.trim()
    else
      inspect(exception)
    end
  end

  defp format_reason(other) when is_atom(other), do: other |> Atom.to_string() |> Phoenix.Naming.humanize()
  defp format_reason(other), do: inspect(other)

  defp strategy_description(:one_for_one), do: "Automatic restart isolates failures to the offending process."

  defp strategy_description(:one_for_all),
    do: "Failure cascades into a coordinated reboot of the entire supervisor subtree."

  defp strategy_description(:rest_for_one), do: "Later children reboot with their sibling when a failure occurs upstream."

  ## Rendering

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:canvas_nodes, @canvas_nodes)
      |> assign(:strategy_options, @strategy_options)
      |> assign(:crash_options, @crash_options)

    ~H"""
    <Layouts.demo flash={@flash}>
      <div class="min-h-screen w-full flex flex-col gap-8 px-6 sm:px-10 py-10 bg-[#11131c] text-slate-200">
        <div class="flex flex-col xl:flex-row gap-6 w-full">
          <div class="flex-1 bg-[#1a1e2b] border border-white/10 rounded-3xl p-6 relative overflow-hidden shadow-[0_20px_60px_rgba(0,0,0,0.35)]">
            <div
              id="worker-network"
              phx-hook="ConnectorCanvas"
              class="relative w-full min-h-[620px]"
            >
              <svg
                id="worker-network-connectors"
                data-role="connector-layer"
                class="absolute inset-0 w-full h-full pointer-events-none"
                xmlns="http://www.w3.org/2000/svg"
                preserveAspectRatio="none"
                phx-update="ignore"
              >
              </svg>

              <div
                :for={node <- @canvas_nodes}
                id={"node-" <> to_string(node.key)}
                data-node-key={node.key}
                data-connector-class={
                  if(node.key != :supervisor,
                    do: line_activity_class(@worker_states[node.key].status)
                  )
                }
                class={[
                  "absolute -translate-x-1/2 -translate-y-1/2 w-[200px] min-h-[200px] rounded-3xl px-5 py-5 flex flex-col gap-6 border-2 backdrop-blur transition-colors duration-300",
                  node.key == :supervisor && "bg-[#201d29] border-amber-300/70",
                  node.key != :supervisor && "bg-slate-900/70",
                  node.key != :supervisor && node_border(@worker_states, node.key)
                ]}
                style={"left: #{node.x}%; top: #{node.y}%;"}
              >
                <div class="flex items-center justify-between gap-4">
                  <div class="flex flex-col gap-1">
                    <span class="text-xs uppercase tracking-[0.3em] text-white/50">
                      {(node.key == :supervisor && "Supervisor") || "Worker"}
                    </span>
                    <h3 class="text-lg font-semibold text-white">{node.name}</h3>
                  </div>
                  <div
                    class={["w-3 h-3 rounded-full shadow-lg", status_pulse(@worker_states, node.key)]}
                    style={"background:" <> (node.key == :supervisor && "#e2a478" || Map.get(@worker_states, node.key).color)}
                  />
                </div>

                <dl :if={node.key != :supervisor} class="flex-1 space-y-3 text-sm text-white/70">
                  <div class="flex items-center justify-between gap-3">
                    <dt class="text-xs font-medium uppercase tracking-[0.18em] text-white/55">
                      Status
                    </dt>
                    <dd>
                      <span class={[
                        "px-2 py-1 rounded-lg text-xs font-semibold uppercase tracking-wide",
                        status_classes(@worker_states[node.key].status)
                      ]}>
                        {worker_status_label(@worker_states[node.key].status)}
                      </span>
                    </dd>
                  </div>
                  <div class="flex items-center justify-between gap-3">
                    <dt class="text-xs font-medium uppercase tracking-[0.18em] text-white/55">
                      Policy
                    </dt>
                    <dd class="font-semibold text-white text-right">
                      {policy_label(@worker_states[node.key].restart)}
                    </dd>
                  </div>
                  <div class="flex items-center justify-between gap-3">
                    <dt class="text-xs font-medium uppercase tracking-[0.18em] text-white/55">
                      Restarts
                    </dt>
                    <dd class="font-semibold text-white text-right tabular-nums">
                      {@worker_states[node.key].restarts}
                    </dd>
                  </div>
                  <div class="flex items-center justify-between gap-3">
                    <dt class="text-xs font-medium uppercase tracking-[0.18em] text-white/55">
                      Crashes
                    </dt>
                    <dd class="font-semibold text-white text-right tabular-nums">
                      {@worker_states[node.key].crashes}
                    </dd>
                  </div>
                </dl>

                <button
                  :if={node.key != :supervisor}
                  type="button"
                  class="w-full mt-auto flex items-center justify-center gap-2 rounded-xl border border-white/20 text-white/80 hover:text-white hover:border-white/60 transition-all py-2 text-sm font-medium disabled:opacity-40 disabled:cursor-not-allowed"
                  phx-click="crash_worker"
                  phx-value-worker={node.key}
                  id={"trigger-" <> to_string(node.key)}
                  disabled={@worker_states[node.key].pid == nil}
                >
                  <.icon name="hero-fire" class="w-4 h-4" /> Crash Worker
                </button>
              </div>
            </div>
          </div>

          <aside class="w-full xl:w-[340px] space-y-6">
            <div class="bg-white/5 border border-white/10 rounded-3xl p-6 shadow-xl shadow-black/30 space-y-5">
              <div class="space-y-2">
                <div class="space-y-1">
                  <h3 class="text-lg font-semibold text-white">{strategy_name(@strategy)}</h3>
                  <p class="text-xs text-white/60 leading-relaxed">{@strategy_description}</p>
                </div>
              </div>

              <.form for={@control_form} id="fault-controls" class="space-y-3">
                <.input
                  field={@control_form[:strategy]}
                  type="select"
                  options={Enum.map(@strategy_options, &{&1.label, &1.value})}
                  phx-change="select_strategy"
                  class="w-full px-4 py-2 rounded-xl text-sm font-medium border border-white/10 bg-slate-900/60 text-white focus:ring-2 focus:ring-amber-400/70"
                />
                <.input
                  field={@control_form[:crash_type]}
                  type="select"
                  options={Enum.map(@crash_options, &{&1.label, &1.value})}
                  phx-change="select_crash"
                  class="w-full px-4 py-2 rounded-xl text-sm font-medium border border-white/10 bg-slate-900/60 text-white focus:ring-2 focus:ring-rose-400/70"
                />
              </.form>

              <button
                type="button"
                id="toggle-system"
                phx-click={(@system_running? && "stop_system") || "start_system"}
                class={[
                  "w-full px-6 py-2 rounded-xl font-semibold transition-colors transition-transform duration-200",
                  "bg-gradient-to-r from-[#89b8c2]/90 to-[#84a0c6]/90 text-slate-900",
                  "hover:from-[#a6c6d1] hover:to-[#8fb5c2]",
                  "focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#89b8c2] focus-visible:ring-offset-[#1a1e2b]",
                  @system_running? && "hover:scale-[1.01]",
                  !@system_running? && "hover:scale-[1.03]"
                ]}
              >
                <span class="inline-flex items-center justify-center gap-2">
                  <.icon
                    name={if @system_running?, do: "hero-pause-circle", else: "hero-power"}
                    class="w-4 h-4"
                  />
                  {if @system_running?, do: "Stop", else: "Start"}
                </span>
              </button>
            </div>

            <div class="bg-white/5 border border-white/10 rounded-3xl p-6 shadow-xl shadow-black/30">
              <h4 class="text-sm uppercase tracking-[0.25em] text-white/60 mb-4">
                Worker Stateboard
              </h4>
              <div class="space-y-4">
                <div
                  :for={key <- @worker_order}
                  class="flex items-center justify-between gap-3"
                >
                  <% worker = @worker_states[key] %>
                  <div class="flex items-center gap-4">
                    <span
                      class="inline-flex items-center justify-center w-10 h-10 rounded-full font-semibold text-slate-900"
                      style={"background: #{worker.color};"}
                    >
                      {String.upcase(String.first(to_string(key)))}
                    </span>
                    <div>
                      <p class="text-sm font-semibold text-white">{worker.name}</p>
                      <p class="text-xs text-white/60 whitespace-nowrap truncate max-w-[180px]">
                        Last exit: {(worker.last_exit_reason &&
                                       compact_reason(worker.last_exit_reason)) ||
                          "--"}
                      </p>
                    </div>
                  </div>
                  <div class="text-right">
                    <p class="text-xs text-white/60">Restarts</p>
                    <p class="text-lg font-semibold text-white">{worker.restarts}</p>
                  </div>
                </div>
              </div>
            </div>

            <div class="bg-white/5 border border-white/10 rounded-3xl p-6 h-[320px] flex flex-col">
              <div class="flex items-center justify-between mb-3">
                <h4 class="text-sm uppercase tracking-[0.25em] text-white/60">Event Stream</h4>
                <span class="text-xs text-white/50">Realtime</span>
              </div>
              <div id="event-stream" phx-update="stream" class="flex-1 overflow-y-auto pr-2 space-y-3">
                <div
                  :for={{id, event} <- @streams.events}
                  id={id}
                  class={[
                    "rounded-2xl border border-white/10 bg-gradient-to-r p-3 text-slate-900/90",
                    event.accent
                  ]}
                >
                  <div class="flex items-center justify-between gap-2">
                    <div class="flex items-center gap-2">
                      <div class="w-8 h-8 rounded-full bg-white/90 flex items-center justify-center text-slate-900 shadow-lg">
                        <.icon name={event.icon} class="w-4 h-4" />
                      </div>
                      <div>
                        <p class="text-sm font-semibold">{event.message}</p>
                        <p :if={event.detail} class="text-xs text-slate-800/80">{event.detail}</p>
                      </div>
                    </div>
                    <span class="text-xs font-semibold text-slate-900/70">
                      {format_timestamp(event.timestamp)}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </aside>
        </div>
      </div>
    </Layouts.demo>
    """
  end

  defp status_pulse(_worker_states, :supervisor), do: "animate-ping"

  defp status_pulse(worker_states, key) do
    case worker_states[key].status do
      :running -> "shadow-[0_0_15px_rgba(180,190,130,0.55)]"
      :pending -> "animate-ping"
      :restarting -> "animate-pulse"
      :booting -> "animate-pulse"
      _ -> "opacity-50"
    end
  end

  defp line_activity_class(:running), do: "opacity-90"
  defp line_activity_class(:restarting), do: "animate-pulse opacity-70"
  defp line_activity_class(:pending), do: "animate-pulse opacity-80"
  defp line_activity_class(:booting), do: "animate-pulse opacity-80"
  defp line_activity_class(_), do: "opacity-30"

  defp node_border(worker_states, key) do
    case worker_states[key].status do
      :running -> "border-emerald-300/80"
      :pending -> "border-rose-400/80"
      :restarting -> "border-amber-300/80"
      :booting -> "border-cyan-300/80"
      :offline -> "border-slate-600/70"
      _ -> "border-slate-700/60"
    end
  end

  defp worker_status_label(:running), do: "Running"
  defp worker_status_label(:booting), do: "Booting"
  defp worker_status_label(:restarting), do: "Restarting"
  defp worker_status_label(:offline), do: "Stopped"
  defp worker_status_label(:pending), do: "Crashing"
  defp worker_status_label(_), do: "--"

  defp status_classes(:running), do: "bg-emerald-400/80 text-slate-900"
  defp status_classes(:booting), do: "bg-amber-300/80 text-slate-900 animate-pulse"
  defp status_classes(:restarting), do: "bg-cyan-300/70 text-slate-900 animate-pulse"
  defp status_classes(:pending), do: "bg-rose-400/80 text-slate-900 animate-pulse"
  defp status_classes(_), do: "bg-slate-600/70 text-slate-200"

  defp strategy_name(:one_for_one), do: "One for One"
  defp strategy_name(:one_for_all), do: "One for All"
  defp strategy_name(:rest_for_one), do: "Rest for One"

  defp format_timestamp(ts) do
    Calendar.strftime(ts, "%H:%M:%S")
  rescue
    _ -> "--:--"
  end
end
