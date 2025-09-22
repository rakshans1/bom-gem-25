defmodule GemWeb.ProcessDemoLive do
  @moduledoc false
  use GemWeb, :live_view

  def mount(_params, _session, socket) do
    selected_count = "1000000"

    {:ok,
     socket
     |> assign(:process_count, 0)
     |> assign(:status, :idle)
     |> assign(:execution_time, nil)
     |> assign(:progress, 0)
     |> assign(:selected_count, selected_count)
     |> assign(:form, to_form(%{"count" => selected_count}, as: :demo))}
  end

  defp run_process_demo(parent_pid, count) do
    start_time = System.monotonic_time(:millisecond)

    # Split into batches for progress updates
    batch_size = max(1, div(count, 100))

    1..count
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.each(fn {batch, index} ->
      # Spawn processes in this batch
      Enum.each(batch, fn _i ->
        spawn(fn ->
          # Simulate very light work
          Process.sleep(Enum.random(1..10))
          # Don't actually print for performance
          # IO.puts("Process #{i} finished")
        end)
      end)

      # Update progress
      progress = min(100, round((index + 1) * 100 / 100))
      send(parent_pid, {:demo_progress, progress})

      # Small delay to show progress visually
      Process.sleep(10)
    end)

    end_time = System.monotonic_time(:millisecond)
    execution_time = end_time - start_time

    send(parent_pid, {:demo_complete, execution_time})
  end

  def handle_event("select_count", %{"demo" => %{"count" => count_str}}, socket) do
    {:noreply,
     socket
     |> assign(:selected_count, count_str)
     |> assign(:form, to_form(%{"count" => count_str}, as: :demo))
     |> assign(:status, :idle)
     |> assign(:execution_time, nil)
     |> assign(:progress, 0)
     |> assign(:process_count, 0)}
  end

  def handle_event("start_demo", _params, socket) do
    count = String.to_integer(socket.assigns.selected_count)

    socket =
      socket
      |> assign(:process_count, count)
      |> assign(:status, :running)
      |> assign(:execution_time, nil)
      |> assign(:progress, 0)

    # Keep selected_count unchanged so dropdown selection persists

    # Start the demo in a separate process
    pid = self()
    spawn(fn -> run_process_demo(pid, count) end)

    {:noreply, socket}
  end

  def handle_event("reset_demo", _params, socket) do
    {
      :noreply,
      socket
      |> assign(:process_count, 0)
      |> assign(:status, :idle)
      |> assign(:execution_time, nil)
      |> assign(:progress, 0)
      # Keep selected_count unchanged so dropdown selection persists
    }
  end

  def handle_info({:demo_progress, progress}, socket) do
    {:noreply, assign(socket, :progress, progress)}
  end

  def handle_info({:demo_complete, execution_time}, socket) do
    {:noreply,
     socket
     |> assign(:status, :completed)
     |> assign(:execution_time, execution_time)
     |> assign(:progress, 100)}
  end

  defp format_number(number) do
    number
    |> to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_seconds(ms) when is_integer(ms) do
    Float.round(ms / 1000, 2)
  end

  defp get_processes_spawned(progress, total_count) do
    round(progress * total_count / 100)
  end

  def render(assigns) do
    ~H"""
    <Layouts.demo flash={@flash}>
      <div
        class="min-h-screen p-8"
        style="background-color: #161821; color: #c6c8d1; font-family: 'Inter', sans-serif;"
      >
        <div class="max-w-4xl mx-auto">
          <div class="rounded-xl p-8" style="background-color: #2e3244; border: 1px solid #1e2132;">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
              <div class="space-y-4">
                <h3 class="text-2xl font-semibold" style="color: #84a0c6;">Process Count</h3>
                <div class="space-y-2">
                  <label class="block text-sm" style="color: #c6c8d1;">
                    Number of processes to spawn:
                  </label>
                  <.form for={@form} id="process-form" phx-change="select_count">
                    <.input
                      field={@form[:count]}
                      type="select"
                      options={[
                        {"1,000 processes", "1000"},
                        {"10,000 processes", "10000"},
                        {"100,000 processes", "100000"},
                        {"1,000,000 processes", "1000000"}
                      ]}
                      class="w-full px-4 py-2 rounded-lg focus:outline-none focus:ring-2"
                      style="background-color: #1e2132; border: 1px solid #6b7089; color: #c6c8d1;"
                      disabled={@status == :running}
                    />
                  </.form>
                </div>
              </div>

              <div class="space-y-4">
                <h3 class="text-2xl font-semibold" style="color: #89b8c2;">Status</h3>
                <div class="space-y-2">
                  <div class="flex items-center gap-3">
                    <div
                      class={[
                        "w-3 h-3 rounded-full",
                        @status == :idle && "animate-pulse"
                      ]}
                      style={
                        case @status do
                          :idle -> "background-color: #6b7089;"
                          :running -> "background-color: #e2a478; animation: pulse 1s infinite;"
                          :completed -> "background-color: #b4be82;"
                        end
                      }
                    >
                    </div>
                    <span class="text-lg capitalize" style="color: #c6c8d1;">{@status}</span>
                  </div>
                  <div :if={@execution_time} style="color: #c6c8d1;">
                    Execution time:
                    <span style="font-family: 'Fira Code', monospace; color: #b4be82;">
                      {@execution_time}ms
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <div :if={@status == :running or @status == :completed} class="mb-8">
              <div class="flex justify-between text-sm mb-2" style="color: #c6c8d1;">
                <span>Progress</span>
                <span>
                  {@progress}% ({format_number(get_processes_spawned(@progress, @process_count))} / {format_number(
                    @process_count
                  )} processes)
                </span>
              </div>
              <div class="w-full rounded-full h-4 relative" style="background-color: #1e2132;">
                <div
                  class="h-4 rounded-full transition-all duration-300 flex items-center justify-center"
                  style={"width: #{@progress}%; background: linear-gradient(135deg, #84a0c6, #89b8c2);"}
                >
                  <span :if={@progress > 20} class="text-xs font-semibold" style="color: #161821;">
                    {@progress}%
                  </span>
                </div>
              </div>
            </div>

            <div class="flex gap-4 justify-center">
              <button
                phx-click="start_demo"
                disabled={@status == :running}
                class="px-8 py-3 rounded-lg font-semibold text-lg transition-all focus:outline-none"
                style={
                  if @status == :running do
                    "background-color: #6b7089; cursor: not-allowed; color: #c6c8d1;"
                  else
                    "background: linear-gradient(135deg, #84a0c6, #89b8c2); color: #161821; hover:opacity-90;"
                  end
                }
              >
                {if @status == :running, do: "Running...", else: "Spawn"}
              </button>

              <button
                :if={@status == :completed}
                phx-click="reset_demo"
                class="px-8 py-3 rounded-lg font-semibold text-lg transition-all focus:outline-none"
                style="background-color: #2e3244; color: #c6c8d1; border: 1px solid #6b7089; hover:background-color: #6b7089;"
              >
                Reset
              </button>
            </div>

            <div
              :if={@status == :completed}
              class="mt-8 p-6 rounded-lg"
              style="background-color: rgba(180, 190, 130, 0.1); border: 1px solid #b4be82;"
            >
              <h4 class="text-xl font-semibold mb-2" style="color: #b4be82;">Complete!</h4>
              <div class="space-y-2" style="color: #c6c8d1;">
                <p>
                  ✅ Successfully spawned
                  <span style="font-family: 'Fira Code', monospace; color: #89b8c2;">
                    {format_number(@process_count)}
                  </span>
                  processes
                </p>
                <p>
                  ⚡ Total execution time:
                  <span style="font-family: 'Fira Code', monospace; color: #b4be82;">
                    {format_seconds(@execution_time)}s
                  </span>
                </p>
                <p>
                  🚀 Average:
                  <span style="font-family: 'Fira Code', monospace; color: #84a0c6;">
                    {Float.round(@process_count * 1000 / max(@execution_time, 1), 2)}
                  </span>
                  processes per second
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.demo>
    """
  end
end
