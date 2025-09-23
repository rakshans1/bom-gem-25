defmodule GemWeb.PingPongDemoLive do
  @moduledoc false
  use GemWeb, :live_view

  @message_animation_duration_ms 2_000
  @animation_tick_interval 33
  @message_lifespan_ms @message_animation_duration_ms + 2 * @animation_tick_interval

  @impl true
  def mount(_params, _session, socket) do
    default_topology = "hub"
    default_speed = 200
    processes = create_processes(default_topology)

    socket =
      socket
      |> assign(:processes, processes)
      |> assign(:messages, [])
      |> assign(:message_positions, [])
      |> assign(:status, :idle)
      |> assign(:message_count, 0)
      |> assign(:topology, default_topology)
      |> assign(:speed, default_speed)
      |> assign(:controls_form, controls_form(default_topology, default_speed))
      |> assign(:simulation_pid, nil)
      |> assign(:animation_timer_ref, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("start_demo", _params, socket) do
    topology = socket.assigns.topology
    speed = socket.assigns.speed
    processes = create_processes(topology)

    socket =
      socket
      |> maybe_stop_simulation()
      |> cancel_animation_tick()
      |> assign(:processes, processes)
      |> assign(:messages, [])
      |> assign(:message_positions, [])
      |> assign(:status, :running)
      |> assign(:message_count, 0)
      |> assign(:controls_form, controls_form(topology, speed))

    simulation_pid = start_ping_pong_simulation(processes, topology, speed)

    {:noreply, assign(socket, :simulation_pid, simulation_pid)}
  end

  @impl true
  def handle_event("stop_demo", _params, socket) do
    stop_simulation(socket.assigns.simulation_pid)

    {:noreply,
     socket
     |> cancel_animation_tick()
     |> assign(:status, :idle)
     |> assign(:messages, [])
     |> assign(:message_positions, [])
     |> assign(:simulation_pid, nil)}
  end

  @impl true
  def handle_event("update_controls", %{"_target" => ["controls", target], "controls" => params}, socket) do
    socket =
      case target do
        "topology" ->
          topology = Map.get(params, "topology", socket.assigns.topology)

          socket
          |> assign(:topology, topology)
          |> assign(:processes, create_processes(topology))

        "speed" ->
          speed = parse_speed(Map.get(params, "speed"), socket.assigns.speed)
          assign(socket, :speed, speed)

        _ ->
          socket
      end

    socket =
      socket
      |> assign(:controls_form, controls_form(socket.assigns.topology, socket.assigns.speed))
      |> update_message_positions()
      |> maybe_schedule_animation_tick()

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_controls", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:new_message, from_id, to_id, type}, %{assigns: %{status: :running}} = socket) do
    message = %{
      id: 8 |> :crypto.strong_rand_bytes() |> Base.encode64(),
      from: from_id,
      to: to_id,
      type: type,
      timestamp: System.monotonic_time(:millisecond)
    }

    messages = Enum.take([message | socket.assigns.messages], 50)

    # Remove message after animation
    Process.send_after(self(), {:remove_message, message.id}, @message_lifespan_ms)

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:message_count, socket.assigns.message_count + 1)
     |> update_message_positions()
     |> maybe_schedule_animation_tick()}
  end

  def handle_info({:new_message, _from_id, _to_id, _type}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:remove_message, message_id}, socket) do
    messages = Enum.reject(socket.assigns.messages, &(&1.id == message_id))

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> update_message_positions()
     |> maybe_schedule_animation_tick()}
  end

  @impl true
  def handle_info(:animation_tick, socket) do
    socket =
      socket
      |> assign(:animation_timer_ref, nil)
      |> update_message_positions()

    if socket.assigns.status == :running and socket.assigns.messages != [] do
      {:noreply, maybe_schedule_animation_tick(socket)}
    else
      {:noreply, socket}
    end
  end

  defp create_processes("chain") do
    [
      %{id: "p1", name: "Process A", x: 10, y: 40, color: "#84a0c6"},
      %{id: "p2", name: "Process B", x: 35, y: 40, color: "#89b8c2"},
      %{id: "p3", name: "Process C", x: 60, y: 40, color: "#b4be82"},
      %{id: "p4", name: "Process D", x: 85, y: 40, color: "#e2a478"}
    ]
  end

  defp create_processes("ring") do
    [
      %{id: "p1", name: "Process A", x: 50, y: 15, color: "#84a0c6"},
      %{id: "p2", name: "Process B", x: 75, y: 40, color: "#89b8c2"},
      %{id: "p3", name: "Process C", x: 50, y: 65, color: "#b4be82"},
      %{id: "p4", name: "Process D", x: 25, y: 40, color: "#e2a478"}
    ]
  end

  defp create_processes("hub") do
    [
      %{id: "p1", name: "Hub", x: 50, y: 40, color: "#e2a478"},
      %{id: "p2", name: "Worker A", x: 25, y: 20, color: "#84a0c6"},
      %{id: "p3", name: "Worker B", x: 75, y: 20, color: "#89b8c2"},
      %{id: "p4", name: "Worker C", x: 75, y: 60, color: "#b4be82"},
      %{id: "p5", name: "Worker D", x: 25, y: 60, color: "#c6c8d1"}
    ]
  end

  defp start_ping_pong_simulation(processes, topology, speed) do
    parent = self()

    spawn_link(fn ->
      ping_pong_loop(parent, processes, topology, speed)
    end)
  end

  defp ping_pong_loop(parent, processes, topology, speed) do
    interval = message_interval(speed)

    case topology do
      "chain" -> chain_messages(parent, processes, interval)
      "ring" -> ring_messages(parent, processes, interval)
      "hub" -> hub_messages(parent, processes, interval)
    end

    receive do
      :stop -> :ok
    after
      0 -> ping_pong_loop(parent, processes, topology, speed)
    end
  end

  defp chain_messages(_parent, processes, _interval) when length(processes) < 2, do: :ok

  defp chain_messages(parent, processes, interval) do
    processes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [from, to] ->
      message_type = Enum.random(["ping", "pong", "data"])
      send(parent, {:new_message, from.id, to.id, message_type})
      Process.sleep(interval)
    end)
  end

  defp ring_messages(_parent, processes, _interval) when length(processes) < 2, do: :ok

  defp ring_messages(parent, processes, interval) do
    [first | rest] = processes
    ring_pairs = Enum.zip(processes, rest ++ [first])

    Enum.each(ring_pairs, fn {from, to} ->
      message_type = Enum.random(["ping", "pong", "data"])
      send(parent, {:new_message, from.id, to.id, message_type})
      Process.sleep(interval)
    end)
  end

  defp hub_messages(_parent, [_hub], _interval), do: :ok
  defp hub_messages(_parent, [], _interval), do: :ok

  defp hub_messages(parent, [hub | workers], interval) do
    worker = Enum.random(workers)
    send(parent, {:new_message, hub.id, worker.id, "task"})
    Process.sleep(interval)

    send(parent, {:new_message, worker.id, hub.id, "result"})
    Process.sleep(interval)

    if length(workers) >= 2 and Enum.random(1..3) == 1 do
      [w1, w2] = Enum.take_random(workers, 2)
      send(parent, {:new_message, w1.id, w2.id, "gossip"})
      Process.sleep(interval)
    end
  end

  defp message_color(type) do
    case type do
      "ping" -> "#84a0c6"
      "pong" -> "#89b8c2"
      "data" -> "#b4be82"
      "task" -> "#e2a478"
      "result" -> "#c6c8d1"
      "gossip" -> "#9d79d6"
      _ -> "#6b7089"
    end
  end

  defp get_process_by_id(processes, id) do
    Enum.find(processes, &(&1.id == id)) || %{id: id, name: "Unknown", color: "#6b7089"}
  end

  defp controls_form(topology, speed) do
    to_form(%{"topology" => topology, "speed" => Integer.to_string(speed)}, as: :controls)
  end

  defp parse_speed(nil, fallback), do: fallback

  defp parse_speed(value, fallback) do
    case Integer.parse(to_string(value)) do
      {parsed, ""} -> parsed
      _ -> fallback
    end
  end

  defp maybe_stop_simulation(socket) do
    stop_simulation(socket.assigns.simulation_pid)
    assign(socket, :simulation_pid, nil)
  end

  defp stop_simulation(nil), do: :ok

  defp stop_simulation(pid) when is_pid(pid) do
    if Process.alive?(pid), do: send(pid, :stop)
    :ok
  end

  defp message_interval(speed) when is_integer(speed) and speed > 0, do: speed
  defp message_interval(_), do: 500

  defp message_positions(messages, processes) do
    messages
    |> Enum.sort_by(& &1.timestamp, :asc)
    |> Enum.map(fn message ->
      {message, calculate_message_position(message, processes)}
    end)
  end

  defp update_message_positions(socket) do
    positions = message_positions(socket.assigns.messages, socket.assigns.processes)
    assign(socket, :message_positions, positions)
  end

  defp animation_frame_seconds do
    Float.round(@animation_tick_interval / 1000, 3)
  end

  defp control_select_classes do
    [
      "w-full rounded-lg border border-[#6b7089] bg-[#1e2132] px-4 py-2 text-[#c6c8d1]",
      "focus:outline-none focus:ring-2 focus:ring-[#84a0c6] focus:border-[#84a0c6]",
      "transition-colors shadow-sm"
    ]
  end

  defp maybe_schedule_animation_tick(socket) do
    cond do
      socket.assigns.animation_timer_ref != nil ->
        socket

      socket.assigns.messages == [] ->
        socket

      true ->
        ref = Process.send_after(self(), :animation_tick, @animation_tick_interval)
        assign(socket, :animation_timer_ref, ref)
    end
  end

  defp cancel_animation_tick(socket) do
    if ref = socket.assigns.animation_timer_ref do
      Process.cancel_timer(ref, async: true, info: false)
    end

    assign(socket, :animation_timer_ref, nil)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.demo flash={@flash}>
      <div
        class="min-h-screen p-8"
        style="background-color: #161821; color: #c6c8d1; font-family: 'Inter', sans-serif;"
      >
        <div class="max-w-6xl mx-auto">
          <div class="rounded-xl p-8" style="background-color: #2e3244; border: 1px solid #1e2132;">
            <.form for={@controls_form} id="ping-pong-controls" phx-change="update_controls">
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                <div class="space-y-4">
                  <h3 class="text-xl font-semibold" style="color: #84a0c6;">Network Topology</h3>
                  <.input
                    field={@controls_form[:topology]}
                    type="select"
                    options={[
                      {"Chain (A→B→C→D)", "chain"},
                      {"Ring (A→B→C→D→A)", "ring"},
                      {"Hub & Spoke", "hub"}
                    ]}
                    class={control_select_classes()}
                    disabled={@status == :running}
                  />
                </div>

                <div class="space-y-4">
                  <h3 class="text-xl font-semibold" style="color: #89b8c2;">Message Speed</h3>
                  <.input
                    field={@controls_form[:speed]}
                    type="select"
                    options={[
                      {"Fast (200ms)", "200"},
                      {"Normal (500ms)", "500"},
                      {"Slow (1s)", "1000"}
                    ]}
                    class={control_select_classes()}
                    disabled={@status == :running}
                  />
                </div>

                <div class="space-y-4">
                  <h3 class="text-xl font-semibold" style="color: #b4be82;">Status</h3>
                  <div class="flex items-center gap-3">
                    <div
                      class={["w-3 h-3 rounded-full", @status == :running && "animate-pulse"]}
                      style={
                        if @status == :running do
                          "background-color: #b4be82;"
                        else
                          "background-color: #6b7089;"
                        end
                      }
                    >
                    </div>
                    <span class="text-lg capitalize" style="color: #c6c8d1;">{@status}</span>
                  </div>
                  <div style="color: #c6c8d1;">
                    Messages sent:
                    <span style="color: #84a0c6; font-family: 'Fira Code', monospace;">
                      {@message_count}
                    </span>
                  </div>
                </div>
              </div>
            </.form>

            <div class="mb-8">
              <div
                class="relative w-full rounded-lg"
                style="height: 400px; background-color: #1e2132; border: 1px solid #6b7089;"
              >
                <div
                  :for={process <- @processes}
                  class="absolute transform -translate-x-1/2 -translate-y-1/2 transition-all duration-300"
                  style={"left: #{process.x}%; top: #{process.y}%;"}
                >
                  <div
                    class="w-16 h-16 rounded-full flex items-center justify-center text-white font-semibold text-sm shadow-lg border-2"
                    style={"background-color: #{process.color}; border-color: #{process.color}; box-shadow: 0 0 20px #{process.color}40;"}
                  >
                    {String.slice(process.name, -1, 1)}
                  </div>
                  <div class="text-center mt-2 text-xs" style="color: #c6c8d1;">
                    {process.name}
                  </div>
                </div>

                <div
                  :for={{message, position} <- @message_positions}
                  id={"message-#{message.id}"}
                  class="absolute transform -translate-x-1/2 -translate-y-1/2"
                  style={"left: #{position.x}%; top: #{position.y}%; transition: all #{animation_frame_seconds()}s linear;"}
                >
                  <div
                    class="w-3 h-3 rounded-full animate-pulse"
                    style={"background-color: #{message_color(message.type)}; box-shadow: 0 0 10px #{message_color(message.type)};"}
                  >
                  </div>
                </div>
              </div>
            </div>

            <div class="mb-8">
              <h4 class="text-lg font-semibold mb-4" style="color: #c6c8d1;">Message Types</h4>
              <div class="grid grid-cols-2 md:grid-cols-6 gap-4">
                <div class="flex items-center gap-2">
                  <div class="w-3 h-3 rounded-full" style="background-color: #84a0c6;"></div>
                  <span class="text-sm" style="color: #c6c8d1;">Ping</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="w-3 h-3 rounded-full" style="background-color: #89b8c2;"></div>
                  <span class="text-sm" style="color: #c6c8d1;">Pong</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="w-3 h-3 rounded-full" style="background-color: #b4be82;"></div>
                  <span class="text-sm" style="color: #c6c8d1;">Data</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="w-3 h-3 rounded-full" style="background-color: #e2a478;"></div>
                  <span class="text-sm" style="color: #c6c8d1;">Task</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="w-3 h-3 rounded-full" style="background-color: #c6c8d1;"></div>
                  <span class="text-sm" style="color: #c6c8d1;">Result</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="w-3 h-3 rounded-full" style="background-color: #9d79d6;"></div>
                  <span class="text-sm" style="color: #c6c8d1;">Gossip</span>
                </div>
              </div>
            </div>

            <div class="flex gap-4 justify-center">
              <button
                phx-click={if @status == :running, do: "stop_demo", else: "start_demo"}
                class="px-8 py-3 rounded-lg font-semibold text-lg transition-all focus:outline-none"
                style={
                  if @status == :running do
                    "background-color: #e27878; color: #161821; hover:opacity-90;"
                  else
                    "background: linear-gradient(135deg, #84a0c6, #89b8c2); color: #161821; hover:opacity-90;"
                  end
                }
              >
                {if @status == :running, do: "Stop Demo", else: "Start Demo"}
              </button>
            </div>

            <div :if={@status == :running and length(@messages) > 0} class="mt-8">
              <h4 class="text-lg font-semibold mb-4" style="color: #c6c8d1;">Recent Messages</h4>
              <div class="space-y-2 max-h-40 overflow-y-auto">
                <div
                  :for={message <- Enum.take(@messages, 10)}
                  class="flex items-center gap-3 text-sm p-2 rounded"
                  style="background-color: rgba(180, 190, 130, 0.05);"
                >
                  <div
                    class="w-2 h-2 rounded-full"
                    style={"background-color: #{message_color(message.type)};"}
                  >
                  </div>
                  <span style="color: #c6c8d1;">
                    <span style="color: #{get_process_by_id(@processes, message.from).color};">
                      {get_process_by_id(@processes, message.from).name}
                    </span>
                    →
                    <span style="color: #{get_process_by_id(@processes, message.to).color};">
                      {get_process_by_id(@processes, message.to).name}
                    </span>
                    :
                    <span style="color: #{message_color(message.type)}; text-transform: capitalize;">
                      {message.type}
                    </span>
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.demo>
    """
  end

  @impl true
  def terminate(_reason, socket) do
    stop_simulation(socket.assigns.simulation_pid)
    cancel_animation_tick(socket)
    :ok
  end

  defp calculate_message_position(message, processes) do
    from_process = get_process_by_id(processes, message.from)
    to_process = get_process_by_id(processes, message.to)

    if from_process && to_process do
      # Calculate progress based on timestamp (simulate 2-second travel time)
      now = System.monotonic_time(:millisecond)
      elapsed = now - message.timestamp
      progress = min(1.0, elapsed / @message_animation_duration_ms)

      # Interpolate position
      x = from_process.x + (to_process.x - from_process.x) * progress
      y = from_process.y + (to_process.y - from_process.y) * progress

      %{x: x, y: y}
    else
      %{x: 50, y: 50}
    end
  end
end
