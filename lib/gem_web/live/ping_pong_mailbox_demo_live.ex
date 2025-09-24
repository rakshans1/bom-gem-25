defmodule GemWeb.PingPongMailboxDemoLive do
  @moduledoc false
  use GemWeb, :live_view

  alias Gem.Demo.PingPongMailbox
  alias Gem.Demo.PingPongMailbox.Message
  alias Phoenix.LiveView.JS

  @speeds %{slow: 900, normal: 600, fast: 300}
  @default_interval @speeds[:slow]
  @speed_order [:slow, :normal, :fast]
  @message_order [:ping, :pong, :data, :task, :result, :gossip]

  @impl true
  def mount(_params, _session, socket) do
    session_ref = "ppm-" <> Integer.to_string(System.unique_integer([:positive]))

    socket =
      socket
      |> assign(:session_ref, session_ref)
      |> assign(:tree_pid, nil)
      |> assign(:processes, initial_processes())
      |> assign(:controls, %{running?: false, speed: :slow, auto_injector?: true})
      |> assign(:message_palette, build_palette())
      |> assign(:metrics, %{messages_sent: 0, messages_processed: 0, queue_depth: %{a: 0, b: 0}, max_queue: %{a: 0, b: 0}})
      |> assign(:auto_tick_ref, nil)
      |> assign(:auto_index, %{a: 0, b: div(length(@message_order), 2)})
      |> assign(:speed_options, @speed_order)
      |> assign(:message_types, @message_order)
      |> stream(:mailbox_a, [])
      |> stream(:mailbox_b, [])
      |> stream(:events, [])
      |> assign(:inflight, %{a: nil, b: nil})

    {:ok, socket}
  end

  @impl true
  def handle_event("start_conversation", _params, %{assigns: %{controls: %{running?: true}}} = socket) do
    {:noreply, socket}
  end

  def handle_event("start_conversation", _params, socket) do
    case start_tree(socket) do
      {:ok, socket} -> {:noreply, socket}
      {:error, socket} -> {:noreply, socket}
    end
  end

  def handle_event("reset_conversation", _params, socket) do
    {:noreply, reset_demo(socket)}
  end

  def handle_event("enqueue", %{"target" => target, "type" => type}, socket) do
    with {:ok, key} <- parse_process_key(target),
         {:ok, message_type} <- parse_message_type(type) do
      {:noreply, enqueue_message(socket, key, message_type, :manual)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("toggle_auto", _params, socket) do
    controls = socket.assigns.controls
    toggled = %{controls | auto_injector?: !controls.auto_injector?}

    socket =
      socket
      |> assign(:controls, toggled)
      |> then(fn sock -> if toggled.auto_injector?, do: schedule_next_tick(sock), else: cancel_tick(sock) end)

    {:noreply, socket}
  end

  def handle_event("set_speed", %{"speed" => speed}, socket) do
    case parse_speed(speed) do
      {:ok, speed_atom} ->
        interval = Map.fetch!(@speeds, speed_atom)

        socket =
          socket
          |> assign(:controls, %{socket.assigns.controls | speed: speed_atom})
          |> broadcast_interval(interval)
          |> schedule_next_tick()

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_process", %{"target" => target}, socket) do
    case parse_process_key(target) do
      {:ok, key} -> {:noreply, toggle_process(socket, key)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:ppm_worker_started, session_ref, key, pid}, %{assigns: %{session_ref: session_ref}} = socket) do
    monitor_ref = Process.monitor(pid)
    interval = Map.fetch!(@speeds, socket.assigns.controls.speed)
    PingPongMailbox.set_interval(pid, interval)

    processes =
      Map.update!(socket.assigns.processes, key, fn process ->
        process
        |> Map.put(:pid, pid)
        |> Map.put(:monitor, monitor_ref)
        |> Map.put(:status, :idle)
        |> Map.put(:paused?, false)
        |> Map.put(:snippet, snippet_for(key, :idle, nil))
      end)

    {:noreply, assign(socket, :processes, processes)}
  end

  def handle_info({:ppm_worker_started, _session_ref, _key, _pid}, socket) do
    {:noreply, socket}
  end

  def handle_info({:ppm_processing_started, session_ref, key, message}, %{assigns: %{session_ref: session_ref}} = socket) do
    socket =
      socket
      |> drop_mailbox_entry(key, message)
      |> update_inflight(key, message)
      |> update_process(key, fn process ->
        process
        |> Map.put(:status, :processing)
        |> Map.put(:current_message, message)
        |> Map.put(:snippet, snippet_for(key, :processing, message))
      end)
      |> update_queue_depth(key, -1)
      |> log_event(:processing_started, key, message)

    {:noreply, socket}
  end

  def handle_info({:ppm_processing_complete, session_ref, key, message}, %{assigns: %{session_ref: session_ref}} = socket) do
    socket =
      socket
      |> update_metrics_processed()
      |> clear_inflight(key)
      |> update_process(key, fn process ->
        paused? = Map.get(process, :paused?, false)
        status = if paused?, do: :paused, else: :idle

        process
        |> Map.put(:status, status)
        |> Map.put(:current_message, nil)
        |> Map.put(:snippet, snippet_for(key, status, nil))
      end)
      |> log_event(:processing_complete, key, message)
      |> maybe_autonext(message)

    {:noreply, socket}
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, socket) do
    {key, processes} = pop_process_by_monitor(socket.assigns.processes, ref, pid)

    socket =
      if key do
        assign(socket, :processes, processes)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(:auto_tick, %{assigns: %{controls: %{running?: true, auto_injector?: true}}} = socket) do
    socket = schedule_next_tick(socket)
    socket = auto_cycle(socket)
    {:noreply, socket}
  end

  def handle_info(:auto_tick, socket) do
    {:noreply, assign(socket, :auto_tick_ref, nil)}
  end

  ## Helpers

  defp start_tree(%{assigns: %{tree_pid: nil, session_ref: session_ref}} = socket) do
    case PingPongMailbox.start_tree(session_ref, self(), interval: @default_interval) do
      {:ok, tree_pid} ->
        socket =
          socket
          |> assign(:tree_pid, tree_pid)
          |> assign(:controls, %{socket.assigns.controls | running?: true})
          |> schedule_next_tick()
          |> log_event(:system, :system, Message.new(:system, label: "Demo started"))

        {:ok, socket}

      {:error, reason} ->
        socket = log_event(socket, :system_error, :system, Message.new(:system, label: inspect(reason)))
        {:error, socket}
    end
  end

  defp start_tree(socket), do: {:ok, socket}

  defp reset_demo(socket) do
    socket = cancel_tick(socket)

    if tree_pid = socket.assigns.tree_pid do
      PingPongMailbox.stop_tree(tree_pid)
    end

    socket
    |> assign(:tree_pid, nil)
    |> assign(:processes, initial_processes())
    |> assign(:controls, %{running?: false, speed: :slow, auto_injector?: true})
    |> assign(:metrics, %{messages_sent: 0, messages_processed: 0, queue_depth: %{a: 0, b: 0}, max_queue: %{a: 0, b: 0}})
    |> assign(:inflight, %{a: nil, b: nil})
    |> assign(:auto_index, %{a: 0, b: div(length(@message_order), 2)})
    |> stream(:mailbox_a, [], reset: true)
    |> stream(:mailbox_b, [], reset: true)
    |> stream(:events, [], reset: true)
  end

  defp enqueue_message(socket, key, type, source) do
    case fetch_worker(socket, key) do
      {:ok, pid} ->
        message = build_message(type, key, source)
        PingPongMailbox.enqueue(pid, message)

        socket
        |> assign(:metrics, increment_sent(socket.assigns.metrics))
        |> update_queue_depth(key, 1)
        |> push_mailbox_entry(key, message)
        |> log_event(:enqueued, key, message)

      :error ->
        socket
    end
  end

  defp schedule_next_tick(%{assigns: %{controls: %{running?: true, auto_injector?: true}}} = socket) do
    socket = cancel_tick(socket)
    interval = tick_interval(socket.assigns.controls.speed)
    ref = Process.send_after(self(), :auto_tick, interval)
    assign(socket, :auto_tick_ref, ref)
  end

  defp schedule_next_tick(socket), do: cancel_tick(socket)

  defp cancel_tick(%{assigns: %{auto_tick_ref: ref}} = socket) when is_reference(ref) do
    Process.cancel_timer(ref)
    assign(socket, :auto_tick_ref, nil)
  end

  defp cancel_tick(socket), do: socket

  defp tick_interval(:fast), do: 450
  defp tick_interval(:normal), do: 800
  defp tick_interval(:slow), do: 1_200
  defp tick_interval(_), do: 900

  defp auto_cycle(socket) do
    Enum.reduce([:a, :b], socket, fn key, acc ->
      if queue_depth(acc, key) < 3 do
        {type, acc} = next_auto_type(acc, key)
        enqueue_message(acc, key, type, :auto)
      else
        acc
      end
    end)
  end

  defp fetch_worker(socket, key) do
    case get_in(socket.assigns.processes, [key, :pid]) do
      pid when is_pid(pid) -> {:ok, pid}
      _ -> :error
    end
  end

  defp initial_processes do
    Map.new([:a, :b], fn key ->
      {key,
       %{
         label: process_label(key),
         pid: nil,
         monitor: nil,
         status: :idle,
         paused?: false,
         current_message: nil,
         snippet: snippet_for(key, :idle, nil)
       }}
    end)
  end

  defp build_palette do
    %{
      ping: %{color: "#84a0c6", label: "Ping"},
      pong: %{color: "#89b8c2", label: "Pong"},
      data: %{color: "#b4be82", label: "Data"},
      task: %{color: "#e2a478", label: "Task"},
      result: %{color: "#c6c8d1", label: "Result"},
      gossip: %{color: "#9d79d6", label: "Gossip"}
    }
  end

  defp parse_process_key("a"), do: {:ok, :a}
  defp parse_process_key("b"), do: {:ok, :b}
  defp parse_process_key(_), do: :error

  defp parse_message_type(type) do
    with {:ok, atom} <- safe_atom(type),
         true <- atom in @message_order do
      {:ok, atom}
    else
      _ -> :error
    end
  end

  defp parse_speed(speed) do
    with {:ok, atom} <- safe_atom(speed),
         true <- atom in @speed_order do
      {:ok, atom}
    else
      _ -> :error
    end
  end

  defp safe_atom(value) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> :error
  end

  defp build_message(type, key, source) do
    direction = if key == :a, do: %{from: :process_b, to: :process_a}, else: %{from: :process_a, to: :process_b}
    sequence = short_sequence()
    payload = %{source: source, sequence: sequence}

    Message.new(type,
      from: direction.from,
      to: direction.to,
      payload: payload,
      label: message_label(type, sequence)
    )
  end

  defp message_label(:data, sequence), do: "data(#{sequence})"
  defp message_label(:task, sequence), do: "task(#{sequence})"
  defp message_label(:result, sequence), do: "result(#{sequence})"
  defp message_label(:gossip, sequence), do: "gossip(#{sequence})"
  defp message_label(type, _sequence), do: Atom.to_string(type)

  defp push_mailbox_entry(socket, :a, message) do
    stream_insert(socket, :mailbox_a, message, at: 0)
  end

  defp push_mailbox_entry(socket, :b, message) do
    stream_insert(socket, :mailbox_b, message, at: 0)
  end

  defp drop_mailbox_entry(socket, :a, message) do
    stream_delete(socket, :mailbox_a, message)
  end

  defp drop_mailbox_entry(socket, :b, message) do
    stream_delete(socket, :mailbox_b, message)
  end

  defp update_inflight(socket, key, message) do
    assign(socket, :inflight, Map.put(socket.assigns.inflight, key, message))
  end

  defp clear_inflight(socket, key) do
    assign(socket, :inflight, Map.put(socket.assigns.inflight, key, nil))
  end

  defp update_process(socket, key, fun) do
    assign(socket, :processes, Map.update!(socket.assigns.processes, key, fun))
  end

  defp update_metrics_processed(socket) do
    assign(socket, :metrics, Map.update!(socket.assigns.metrics, :messages_processed, &(&1 + 1)))
  end

  defp increment_sent(metrics) do
    Map.update!(metrics, :messages_sent, &(&1 + 1))
  end

  defp update_queue_depth(socket, key, delta) do
    metrics = socket.assigns.metrics

    queue_depth = update_in_map(metrics.queue_depth, key, delta)
    max_queue = update_max_queue(metrics.max_queue, queue_depth, key)

    assign(socket, :metrics, %{metrics | queue_depth: queue_depth, max_queue: max_queue})
  end

  defp queue_depth(socket, key) do
    Map.get(socket.assigns.metrics.queue_depth, key, 0)
  end

  defp next_auto_type(socket, key) do
    index = Map.get(socket.assigns.auto_index, key, 0)
    type = Enum.at(@message_order, rem(index, length(@message_order)))
    auto_index = Map.put(socket.assigns.auto_index, key, index + 1)
    {type, assign(socket, :auto_index, auto_index)}
  end

  defp broadcast_interval(socket, interval) do
    Enum.each(socket.assigns.processes, fn {_key, process} ->
      if is_pid(process.pid), do: PingPongMailbox.set_interval(process.pid, interval)
    end)

    socket
  end

  defp toggle_process(socket, key) do
    case fetch_worker(socket, key) do
      {:ok, pid} ->
        paused? = get_in(socket.assigns.processes, [key, :paused?]) || false
        current_message = get_in(socket.assigns.processes, [key, :current_message])
        new_paused? = !paused?

        if paused?, do: PingPongMailbox.resume(pid), else: PingPongMailbox.pause(pid)

        new_status = status_after_toggle(get_in(socket.assigns.processes, [key, :status]), new_paused?, current_message)

        socket
        |> update_process(key, fn process ->
          process
          |> Map.put(:paused?, new_paused?)
          |> Map.put(:status, new_status)
          |> Map.put(:snippet, snippet_for(key, new_status, current_message))
        end)
        |> log_event(
          if(new_paused?, do: :paused, else: :resumed),
          key,
          Message.new(:system, label: toggle_label(new_paused?, key))
        )

      :error ->
        socket
    end
  end

  defp status_after_toggle(_current_status, true, current_message) do
    if current_message, do: :processing, else: :paused
  end

  defp status_after_toggle(_current_status, false, current_message) do
    if current_message, do: :processing, else: :idle
  end

  defp toggle_label(true, key), do: process_label(key) <> " paused"
  defp toggle_label(false, key), do: process_label(key) <> " resumed"

  defp update_in_map(map, key, delta) do
    Map.update(map, key, max(delta, 0), fn value -> max(value + delta, 0) end)
  end

  defp update_max_queue(max_map, queue_depth, key) do
    current = Map.fetch!(queue_depth, key)
    Map.update(max_map, key, current, &max(&1, current))
  end

  defp log_event(socket, type, key, message) do
    entry = %{
      id: "evt-" <> Integer.to_string(System.unique_integer([:positive])),
      type: type,
      process: key,
      message: message,
      at: DateTime.utc_now()
    }

    stream_insert(socket, :events, entry, at: 0)
  end

  defp maybe_autonext(socket, %Message{} = message) do
    case relay_target(message) do
      {:ok, key, type} -> enqueue_message(socket, key, type, :relay)
      :skip -> socket
    end
  end

  defp maybe_autonext(socket, _message), do: socket

  defp relay_target(%Message{payload: payload} = message) do
    payload = payload || %{}

    with dest when dest in [:a, :b] <- destination_to_key(message.to),
         source = Map.get(payload, :source, :manual),
         false <- source in [:relay],
         {:ok, reply_type} <- relay_type(message.type) do
      {:ok, other_process(dest), reply_type}
    else
      _ -> :skip
    end
  end

  defp relay_type(:ping), do: {:ok, :pong}
  defp relay_type(:pong), do: {:ok, :ping}
  defp relay_type(:data), do: {:ok, :task}
  defp relay_type(:task), do: {:ok, :result}
  defp relay_type(:result), do: {:ok, :gossip}
  defp relay_type(:gossip), do: :skip
  defp relay_type(_), do: :skip

  defp other_process(:a), do: :b
  defp other_process(:b), do: :a

  defp short_sequence do
    [:positive]
    |> System.unique_integer()
    |> rem(100)
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp snippet_for(key, status, message)

  defp snippet_for(key, :processing, %Message{type: type, payload: %{sequence: seq}}) do
    %{
      heading: heading_for(key),
      lines: processing_lines(key, type, seq)
    }
  end

  defp snippet_for(key, :offline, _message) do
    %{
      heading: heading_for(key),
      lines: [
        %{text: "# awaiting start", variant: :comment}
      ]
    }
  end

  defp snippet_for(key, :paused, _message) do
    %{
      heading: heading_for(key),
      lines: [
        %{text: "# paused – mailbox growing", variant: :comment}
      ]
    }
  end

  defp snippet_for(key, _status, _message) do
    %{
      heading: heading_for(key),
      lines: idle_lines(key)
    }
  end

  defp processing_lines(:a, type, seq) do
    pattern = snippet_pattern(type, seq)

    [%{text: "send(process_b, #{pattern})", variant: :active}]
  end

  defp processing_lines(:b, type, seq) do
    pattern = snippet_pattern(type, seq)
    handler = handler_call(type, seq)

    [%{text: "receive #{pattern} -> #{handler}", variant: :active}]
  end

  defp idle_lines(:a) do
    [%{text: "receive msg -> handle_msg(msg)", variant: :secondary}]
  end

  defp idle_lines(:b) do
    [%{text: "receive msg -> dispatch(msg)", variant: :secondary}]
  end

  defp snippet_pattern(:ping, seq), do: "{:ping, #{seq}}"
  defp snippet_pattern(:pong, seq), do: "{:pong, #{seq}}"
  defp snippet_pattern(:data, seq), do: "{:data, #{seq}}"
  defp snippet_pattern(:task, seq), do: "{:task, #{seq}}"
  defp snippet_pattern(:result, seq), do: "{:result, #{seq}}"
  defp snippet_pattern(:gossip, seq), do: "{:gossip, #{seq}}"

  defp handler_call(:ping, seq), do: "handle_ping(#{seq})"
  defp handler_call(:pong, seq), do: "handle_pong(#{seq})"
  defp handler_call(:data, seq), do: "persist(#{seq})"
  defp handler_call(:task, seq), do: "run_task(#{seq})"
  defp handler_call(:result, seq), do: "store_result(#{seq})"
  defp handler_call(:gossip, seq), do: "propagate(#{seq})"

  defp heading_for(:a), do: "process_a"
  defp heading_for(:b), do: "process_b"

  defp process_label(:a), do: "Process A"
  defp process_label(:b), do: "Process B"
  defp process_label(:system), do: "System"

  defp process_label(other) when is_atom(other) do
    other
    |> Atom.to_string()
    |> String.trim_leading("process_")
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp translucent(color, alpha_hex \\ "26")
  defp translucent("#" <> rest, alpha_hex), do: "#" <> rest <> alpha_hex
  defp translucent(color, alpha_hex), do: color <> alpha_hex

  defp status_label(:processing), do: "Processing"
  defp status_label(:paused), do: "Paused"
  defp status_label(:offline), do: "Offline"
  defp status_label(_), do: "Idle"

  defp status_classes(:processing), do: "bg-[#e2a478]"
  defp status_classes(:paused), do: "bg-[#e2a478]/40 ring-2 ring-[#e2a478]/60"
  defp status_classes(:offline), do: "bg-[#e27878]"
  defp status_classes(_), do: "bg-[#6b7089]/80"

  defp toggle_button_classes(true), do: "border border-white/20 bg-transparent text-white/80 hover:bg-white/10"

  defp toggle_button_classes(false),
    do: "bg-gradient-to-r from-[#89b8c2]/90 to-[#84a0c6]/90 text-slate-900 hover:from-[#a6c6d1] hover:to-[#8fb5c2]"

  defp type_label(type) when is_atom(type) do
    type
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.upcase()
  end

  defp message_sequence(%Message{payload: %{sequence: seq}}) when is_integer(seq), do: seq
  defp message_sequence(_), do: nil

  defp message_source(%Message{payload: %{source: source}}), do: source_label(source)
  defp message_source(_), do: "SYSTEM"

  defp source_label(:manual), do: "MANUAL"
  defp source_label(:auto), do: "AUTO"
  defp source_label(:auto_reply), do: "REPLY"
  defp source_label(other) when is_atom(other), do: String.upcase(Atom.to_string(other))
  defp source_label(_), do: "SYSTEM"

  defp format_count(nil), do: "0"

  defp format_count(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end

  defp format_timestamp(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  rescue
    _ -> "--:--:--"
  end

  defp format_timestamp(_), do: "--:--:--"

  defp inflight_position_classes(:left), do: ["right-16", "sm:right-24"]
  defp inflight_position_classes(:right), do: ["left-16", "sm:left-24"]

  defp animation_name(:left), do: "highway-left"
  defp animation_name(:right), do: "highway-right"

  attr :snippet, :map, required: true

  defp snippet_panel(assigns) do
    ~H"""
    <div class="rounded-2xl border border-white/10 bg-[#0f111a]/80 px-5 py-4 shadow-[0_20px_35px_rgba(12,14,24,0.45)] transition-all duration-200">
      <div class="flex items-center justify-between text-xs uppercase tracking-[0.25em] text-white/40">
        <span>{@snippet.heading}</span>
      </div>
      <pre
        phx-no-curly-interpolation
        class="mt-3 flex flex-col gap-1 text-left font-mono text-sm leading-relaxed"
      >
        <code :for={line <- @snippet.lines} class={snippet_line_classes(line.variant)}>
          <%= line.text %>
        </code>
      </pre>
    </div>
    """
  end

  defp snippet_line_classes(:active), do: ["rounded-xl", "bg-white/10", "px-4", "py-1.5", "text-white"]
  defp snippet_line_classes(:comment), do: ["rounded-xl", "px-4", "py-1.5", "text-white/40", "italic"]
  defp snippet_line_classes(:secondary), do: ["rounded-xl", "px-4", "py-1.5", "text-white/70"]
  defp snippet_line_classes(_), do: ["rounded-xl", "px-4", "py-1.5", "text-white/40"]

  attr :message, :any, default: nil
  attr :direction, :atom, required: true
  attr :duration, :integer, default: 600

  defp inflight_marker(%{message: nil} = assigns) do
    ~H"""
    """
  end

  defp inflight_marker(assigns) do
    message = assigns.message
    travel = "calc(100% - 8rem)"

    assigns =
      assigns
      |> assign(:label, String.upcase(to_string(message.label)))
      |> assign(:position_classes, inflight_position_classes(assigns.direction))
      |> assign(:glow, translucent(message.color, "55"))
      |> assign(
        :animation_style,
        "--travel-distance: #{travel}; animation: #{animation_name(assigns.direction)} #{assigns.duration}ms ease-in-out forwards;"
      )

    ~H"""
    <div
      class={["absolute top-1/2", @position_classes]}
      style={@animation_style}
    >
      <div class="flex flex-col items-center gap-2">
        <div class="relative flex h-8 w-8 items-center justify-center">
          <span
            class="absolute inset-0 animate-ping rounded-full"
            style={"background-color: #{translucent(@message.color)};"}
          />
          <span
            class="relative h-4 w-4 rounded-full border border-white/30 shadow-[0_10px_30px_rgba(8,9,18,0.5)]"
            style={"background-color: #{@message.color}; box-shadow: 0 10px 30px #{@glow};"}
          />
        </div>
        <span class="text-[10px] font-semibold uppercase tracking-[0.35em] text-white/40">
          {@label}
        </span>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :color, :string, required: true

  defp legend_chip(assigns) do
    ~H"""
    <div class="flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs uppercase tracking-[0.25em] text-white/60">
      <span class="h-2.5 w-2.5 rounded-full" style={"background-color: #{@color};"} />
      <span>{@label}</span>
    </div>
    """
  end

  attr :entry, :map, required: true

  defp event_entry(assigns) do
    assigns = assign(assigns, :timestamp, format_timestamp(assigns.entry.at))

    ~H"""
    <div
      id={@entry.id}
      class="group flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3 transition-all duration-200 hover:border-white/20 hover:bg-white/10"
    >
      <div class="flex items-center gap-3">
        <span class="h-2.5 w-2.5 rounded-full" style={"background-color: #{@entry.message.color};"} />
        <div class="flex flex-col">
          <span class="text-xs uppercase tracking-[0.25em] text-white/40">
            {process_label(@entry.process)}
          </span>
          <span class="text-sm font-semibold text-white">{@entry.message.label}</span>
        </div>
      </div>
      <div class="flex flex-col items-end text-xs text-white/40">
        <span class="font-mono text-white/50">{type_label(@entry.type)}</span>
        <span>{@timestamp}</span>
      </div>
    </div>
    """
  end

  attr :key, :atom, required: true
  attr :process, :map, required: true
  attr :mailbox_stream, :any, required: true
  attr :metrics, :map, required: true

  defp process_card(assigns) do
    assigns =
      assigns
      |> assign(:queue_depth, Map.get(assigns.metrics.queue_depth, assigns.key, 0))
      |> assign(:max_queue, Map.get(assigns.metrics.max_queue, assigns.key, 0))
      |> assign(:paused?, Map.get(assigns.process, :paused?, false))
      |> assign(:status, Map.get(assigns.process, :status, :idle))

    ~H"""
    <div class="flex h-full flex-col gap-5 rounded-3xl border border-white/10 bg-[#11131c]/65 px-6 py-6 shadow-[0_35px_60px_rgba(9,11,20,0.55)]">
      <div class="flex items-start justify-between">
        <div class="space-y-2">
          <div class="flex items-center gap-3">
            <span class={["h-3 w-3 rounded-full transition-all duration-200", status_classes(@status)]} />
            <span class="text-lg font-semibold text-white">{@process.label}</span>
          </div>
          <p class="text-xs uppercase tracking-[0.3em] text-white/40">{status_label(@status)}</p>
        </div>
        <button
          phx-click="toggle_process"
          phx-value-target={Atom.to_string(@key)}
          class={[
            "rounded-xl px-4 py-2 text-xs font-semibold uppercase tracking-[0.25em] transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#89b8c2] focus-visible:ring-offset-2 focus-visible:ring-offset-[#11131c]",
            toggle_button_classes(@paused?)
          ]}
        >
          <span :if={@paused?}>Resume</span>
          <span :if={!@paused?}>Pause</span>
        </button>
      </div>

      <.snippet_panel snippet={@process.snippet} />

      <div class="space-y-3">
        <div class="flex items-center justify-between text-xs uppercase tracking-[0.25em] text-white/40">
          <span>Mailbox</span>
          <span class="font-mono text-white/50">{format_count(@queue_depth)} waiting</span>
        </div>
        <div
          id={"mailbox-#{@key}"}
          phx-update="stream"
          class="flex h-52 flex-col-reverse gap-3 overflow-y-auto pr-1"
        >
          <div
            id={"mailbox-#{@key}-empty"}
            class="hidden only:flex items-center justify-center rounded-2xl border border-dashed border-white/10 bg-white/5 px-4 py-6 text-xs uppercase tracking-[0.25em] text-white/30"
          >
            Empty mailbox
          </div>
          <div
            :for={{id, message} <- @mailbox_stream}
            id={id}
            phx-mounted={JS.add_class("mailbox-item")}
            phx-remove={
              JS.remove_class("mailbox-item")
              |> JS.add_class("mailbox-item-out")
              |> JS.transition("ease-in duration-200", to: "opacity-0 translate-y-2", time: 200)
            }
            class="group flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3 transition-all duration-200 hover:border-white/20 hover:bg-white/10"
            style={"border-left: 5px solid #{message.color}; background-color: #{translucent(message.color)};"}
          >
            <div class="flex items-center gap-3">
              <span class="h-2.5 w-2.5 rounded-full" style={"background-color: #{message.color};"} />
              <div class="flex flex-col">
                <span class="text-sm font-semibold text-white">{message.label}</span>
                <span class="text-[11px] uppercase tracking-[0.35em] text-white/40">
                  {message_source(message)}
                </span>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <span class="text-[11px] uppercase tracking-[0.25em] text-white/40">
                {type_label(message.type)}
              </span>
              <span :if={seq = message_sequence(message)} class="text-xs font-mono text-white/50">
                #{format_count(seq)}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp destination_to_key(:process_a), do: :a
  defp destination_to_key(:process_b), do: :b
  defp destination_to_key(_), do: nil

  defp pop_process_by_monitor(processes, ref, pid) do
    Enum.reduce(processes, {nil, processes}, fn {key, process}, {hit, acc} ->
      if process.monitor == ref or process.pid == pid do
        updated =
          process
          |> Map.put(:pid, nil)
          |> Map.put(:monitor, nil)
          |> Map.put(:status, :offline)
          |> Map.put(:paused?, false)
          |> Map.put(:current_message, nil)
          |> Map.put(:snippet, snippet_for(key, :offline, nil))

        {key, Map.put(acc, key, updated)}
      else
        {hit, acc}
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.demo flash={@flash}>
      <div class="min-h-screen w-full bg-[#11131c] text-slate-200 px-6 sm:px-10 py-10">
        <div class="mx-auto flex min-h-[80vh] w-full max-w-8xl flex-col gap-8">
          <div class="flex flex-col gap-6 rounded-3xl border border-white/10 bg-[#1a1e2b]/95 p-8 shadow-[0_65px_120px_rgba(8,9,18,0.55)] backdrop-blur">
            <div class="grid gap-6 xl:grid-cols-[520px_minmax(0,1fr)_520px]">
              <.process_card
                key={:a}
                process={@processes[:a]}
                mailbox_stream={@streams.mailbox_a}
                metrics={@metrics}
              />

              <div class="relative flex flex-col gap-6 rounded-3xl border border-white/10 bg-[#11131c]/65 px-6 py-6 shadow-[0_35px_60px_rgba(9,11,20,0.55)]">
                <div class="flex items-center justify-between text-xs uppercase tracking-[0.3em] text-white/40">
                  <span>Messages</span>
                </div>

                <div class="relative h-40 rounded-2xl border border-dashed border-white/10 bg-gradient-to-br from-white/5 via-transparent to-white/5">
                  <div class="absolute left-10 right-10 top-1/2 -translate-y-1/2 border-t border-white/10" />
                  <div class="absolute left-6 top-1/2 -translate-y-1/2 flex h-10 w-10 items-center justify-center rounded-full border border-white/15 bg-white/10 text-xs font-semibold uppercase tracking-[0.3em] text-white/60 shadow-[0_8px_20px_rgba(8,9,18,0.4)]">
                    A
                  </div>
                  <div class="absolute right-6 top-1/2 -translate-y-1/2 flex h-10 w-10 items-center justify-center rounded-full border border-white/15 bg-white/10 text-xs font-semibold uppercase tracking-[0.3em] text-white/60 shadow-[0_8px_20px_rgba(8,9,18,0.4)]">
                    B
                  </div>
                  <.inflight_marker
                    message={@inflight[:a]}
                    direction={:left}
                    duration={tick_interval(@controls.speed)}
                  />
                  <.inflight_marker
                    message={@inflight[:b]}
                    direction={:right}
                    duration={tick_interval(@controls.speed)}
                  />
                </div>

                <div class="flex flex-wrap gap-2">
                  <.legend_chip
                    :for={{_type, spec} <- @message_palette}
                    label={spec.label}
                    color={spec.color}
                  />
                </div>
              </div>

              <.process_card
                key={:b}
                process={@processes[:b]}
                mailbox_stream={@streams.mailbox_b}
                metrics={@metrics}
              />
            </div>

            <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_300px]">
              <div class="flex flex-col gap-4 rounded-3xl border border-white/10 bg-[#11131c]/65 px-6 py-6 shadow-[0_35px_60px_rgba(9,11,20,0.55)]">
                <div class="text-xs uppercase tracking-[0.3em] text-white/40">Controls</div>

                <div class="grid gap-4 sm:grid-cols-3">
                  <div class="rounded-2xl border border-white/10 bg-white/5 px-4 py-1">
                    <p class="text-xs uppercase tracking-[0.3em] text-white/40">Messages Sent</p>
                    <p class="mt-2 text-2xl font-semibold text-white">
                      {format_count(@metrics.messages_sent)}
                    </p>
                  </div>
                  <div class="rounded-2xl border border-white/10 bg-white/5 px-4 py-1">
                    <p class="text-xs uppercase tracking-[0.3em] text-white/40">Processed</p>
                    <p class="mt-2 text-2xl font-semibold text-white">
                      {format_count(@metrics.messages_processed)}
                    </p>
                  </div>
                  <div class="rounded-2xl border border-white/10 bg-white/5 px-4 py-1">
                    <p class="text-xs uppercase tracking-[0.3em] text-white/40">Auto Injector</p>
                    <p class={[
                      "mt-2 text-2xl font-semibold",
                      @controls.auto_injector? && "text-[#b4be82]",
                      !@controls.auto_injector? && "text-white/50"
                    ]}>
                      {(@controls.auto_injector? && "ON") || "OFF"}
                    </p>
                  </div>
                </div>

                <div class="flex flex-wrap items-center gap-3">
                  <button
                    phx-click="start_conversation"
                    disabled={@controls.running?}
                    class={[
                      "inline-flex items-center gap-2 rounded-xl px-6 py-3 text-sm font-semibold uppercase tracking-[0.2em] transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#89b8c2] focus-visible:ring-offset-2 focus-visible:ring-offset-[#11131c]",
                      @controls.running? && "bg-[#6b7089]/60 text-white/70 cursor-not-allowed",
                      !@controls.running? &&
                        "bg-gradient-to-r from-[#89b8c2]/90 to-[#84a0c6]/90 text-slate-900 hover:from-[#a6c6d1] hover:to-[#8fb5c2] hover:scale-[1.02]"
                    ]}
                  >
                    <.icon name="hero-play" class="h-4 w-4" />
                    {(@controls.running? && "Running") || "Start"}
                  </button>

                  <button
                    phx-click="reset_conversation"
                    class="inline-flex items-center gap-2 rounded-xl border border-white/15 px-6 py-3 text-sm font-semibold uppercase tracking-[0.2em] text-white/80 transition-all duration-200 hover:bg-white/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#b4be82] focus-visible:ring-offset-2 focus-visible:ring-offset-[#11131c]"
                  >
                    <.icon name="hero-arrow-path" class="h-4 w-4" /> Reset
                  </button>

                  <div class="ml-auto flex items-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
                    <div>
                      <p class="text-xs uppercase tracking-[0.3em] text-white/40">Auto Injector</p>
                      <p class="text-sm font-semibold text-white">Keeps ≥ 3 messages queued</p>
                    </div>
                    <button
                      phx-click="toggle_auto"
                      class={[
                        "rounded-full px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.25em] transition-all duration-200",
                        @controls.auto_injector? && "bg-[#89b8c2]/20 text-white",
                        !@controls.auto_injector? &&
                          "border border-white/15 text-white/60 hover:bg-white/10"
                      ]}
                    >
                      {(@controls.auto_injector? && "TURN OFF") || "TURN ON"}
                    </button>
                  </div>
                </div>

                <div class="grid gap-4 sm:grid-cols-2">
                  <div class="space-y-2">
                    <p class="text-xs uppercase tracking-[0.3em] text-white/40">Send to Process A</p>
                    <div class="flex flex-wrap gap-2">
                      <button
                        :for={type <- @message_types}
                        phx-click="enqueue"
                        phx-value-target="a"
                        phx-value-type={Atom.to_string(type)}
                        class="rounded-full border px-3 py-2 text-[11px] font-semibold uppercase tracking-[0.25em] text-white transition-all duration-200 hover:translate-y-[-1px]"
                        style={"border-color: #{@message_palette[type].color}; background-color: #{translucent(@message_palette[type].color, "21")};"}
                      >
                        {String.upcase(Atom.to_string(type))}
                      </button>
                    </div>
                  </div>
                  <div class="space-y-2">
                    <p class="text-xs uppercase tracking-[0.3em] text-white/40">Send to Process B</p>
                    <div class="flex flex-wrap gap-2">
                      <button
                        :for={type <- @message_types}
                        phx-click="enqueue"
                        phx-value-target="b"
                        phx-value-type={Atom.to_string(type)}
                        class="rounded-full border px-3 py-2 text-[11px] font-semibold uppercase tracking-[0.25em] text-white transition-all duration-200 hover:translate-y-[-1px]"
                        style={"border-color: #{@message_palette[type].color}; background-color: #{translucent(@message_palette[type].color, "21")};"}
                      >
                        {String.upcase(Atom.to_string(type))}
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <div class="rounded-3xl border border-white/10 bg-[#11131c]/65 px-6 py-6 shadow-[0_35px_60px_rgba(9,11,20,0.55)]">
                <div class="text-xs uppercase tracking-[0.3em] text-white/40">Event Stream</div>
                <div
                  id="event-log"
                  phx-update="stream"
                  class="mt-4 flex max-h-60 flex-col gap-3 overflow-y-auto pr-1"
                >
                  <div
                    class="hidden only:flex items-center justify-center rounded-2xl border border-dashed border-white/10 bg-white/5 px-4 py-6 text-xs uppercase tracking-[0.25em] text-white/30"
                    id="event-log-empty"
                  >
                    Watch events arrive in real time
                  </div>
                  <.event_entry :for={{_, entry} <- @streams.events} entry={entry} />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.demo>
    """
  end
end
