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
      <div class="min-h-screen w-full bg-[#11131c] text-slate-200 px-6 sm:px-10 py-10">
        <div class="mx-auto flex min-h-[80vh] w-full max-w-6xl flex-col gap-8">
          <div class="flex-1 rounded-3xl border border-white/10 bg-[#1a1e2b]/95 p-8 backdrop-blur">
            <div class="grid grid-cols-1 gap-10 lg:grid-cols-2 lg:gap-12">
              <div class="space-y-5">
                <div class="space-y-2">
                  <h3 class="text-xs uppercase tracking-[0.35em] text-white/50">Process Count</h3>
                  <p class="text-2xl font-semibold text-white">Choose how many processes to spawn</p>
                </div>
                <div class="space-y-4">
                  <.form for={@form} id="process-form" phx-change="select_count">
                    <label class="block text-xs font-semibold uppercase tracking-[0.25em] text-white/50 mb-2">
                      Number of processes
                    </label>
                    <.input
                      field={@form[:count]}
                      type="select"
                      options={[
                        {"1,000 processes", "1000"},
                        {"10,000 processes", "10000"},
                        {"100,000 processes", "100000"},
                        {"1,000,000 processes", "1000000"}
                      ]}
                      class="w-full rounded-xl border border-white/10 bg-slate-900/70 px-4 py-2 text-sm font-medium text-white transition focus:ring-2 focus:ring-[#89b8c2] focus:border-transparent disabled:cursor-not-allowed disabled:opacity-60"
                      disabled={@status == :running}
                    />
                  </.form>
                </div>
              </div>

              <div class="space-y-5">
                <div class="space-y-2">
                  <h3 class="text-xs uppercase tracking-[0.35em] text-white/50">Status</h3>
                  <div class="flex items-center gap-3">
                    <div class={[
                      "h-3 w-3 rounded-full transition-all duration-300",
                      @status == :idle && "bg-[#6b7089]/80",
                      @status == :running && "bg-[#e2a478]",
                      @status == :completed && "bg-[#b4be82]"
                    ]} />
                    <span class="text-lg font-semibold capitalize text-white">{@status}</span>
                  </div>
                </div>

                <div class="rounded-2xl border border-white/10 bg-slate-900/60 p-5">
                  <dl class="space-y-3 text-sm text-white/70">
                    <div class="flex items-center justify-between">
                      <dt class="uppercase tracking-[0.22em] text-white/40 text-xs">Processes</dt>
                      <dd class="font-semibold text-white/90">
                        {format_number(@process_count)}
                      </dd>
                    </div>
                    <div :if={@execution_time} class="flex items-center justify-between">
                      <dt class="uppercase tracking-[0.22em] text-white/40 text-xs">Execution</dt>
                      <dd class="font-mono text-sm text-[#b4be82]">
                        {format_seconds(@execution_time)}s
                      </dd>
                    </div>
                    <div class="flex items-center justify-between">
                      <dt class="uppercase tracking-[0.22em] text-white/40 text-xs">Progress</dt>
                      <dd class="font-mono text-sm text-[#89b8c2]">{@progress}%</dd>
                    </div>
                  </dl>
                </div>
              </div>
            </div>

            <div :if={@status in [:running, :completed]} class="mt-12 space-y-4">
              <div class="flex flex-col gap-2 text-sm text-white/70 sm:flex-row sm:items-center sm:justify-between">
                <span class="uppercase tracking-[0.25em] text-white/40">Progress</span>
                <span class="font-mono text-white/90">
                  {@progress}% ({format_number(get_processes_spawned(@progress, @process_count))} / {format_number(
                    @process_count
                  )} processes)
                </span>
              </div>
              <div class="h-5 w-full overflow-hidden rounded-full border border-white/10 bg-slate-900/70">
                <div
                  class="flex h-full items-center justify-center rounded-full bg-gradient-to-r from-[#89b8c2] via-[#84a0c6] to-[#b4be82] text-xs font-semibold text-[#161821] transition-all duration-300"
                  style={"width: #{@progress}%;"}
                >
                  <span :if={@progress > 15}>{@progress}%</span>
                </div>
              </div>
            </div>

            <div class="mt-12 flex flex-wrap items-center justify-center gap-4">
              <button
                phx-click="start_demo"
                disabled={@status == :running}
                class={[
                  "rounded-xl px-8 py-3 text-base font-semibold uppercase tracking-[0.15em] transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#89b8c2] focus-visible:ring-offset-[#1a1e2b]",
                  @status == :running && "bg-[#6b7089]/60 text-white/70 cursor-not-allowed",
                  @status != :running &&
                    "bg-gradient-to-r from-[#89b8c2]/90 to-[#84a0c6]/90 text-slate-900 hover:from-[#a6c6d1] hover:to-[#8fb5c2] hover:scale-[1.02]"
                ]}
              >
                {if @status == :running, do: "Running...", else: "Spawn"}
              </button>

              <button
                :if={@status == :completed}
                phx-click="reset_demo"
                class="rounded-xl border border-white/15 px-8 py-3 text-base font-semibold uppercase tracking-[0.15em] text-white/80 transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#b4be82] focus-visible:ring-offset-[#1a1e2b] hover:bg-white/10 hover:text-white"
              >
                Reset
              </button>
            </div>

            <div
              :if={@status == :completed}
              class="mt-12 rounded-2xl border border-[#b4be82]/50 bg-[#b4be82]/10 p-6 text-sm text-white/80"
            >
              <h4 class="mb-4 text-lg font-semibold text-[#b4be82]">Complete!</h4>
              <ul class="space-y-3">
                <li class="flex items-start gap-3">
                  <div class="mt-1 h-2.5 w-2.5 rounded-full bg-[#89b8c2]" />
                  <span>
                    Spawned
                    <span class="font-mono text-base text-[#89b8c2]">
                      {format_number(@process_count)}
                    </span>
                    processes
                  </span>
                </li>
                <li class="flex items-start gap-3">
                  <div class="mt-1 h-2.5 w-2.5 rounded-full bg-[#b4be82]" />
                  <span>
                    Total execution time
                    <span class="font-mono text-base text-[#b4be82]">
                      {format_seconds(@execution_time)}s
                    </span>
                  </span>
                </li>
                <li class="flex items-start gap-3">
                  <div class="mt-1 h-2.5 w-2.5 rounded-full bg-[#84a0c6]" />
                  <span>
                    Throughput
                    <span class="font-mono text-base text-[#84a0c6]">
                      {Float.round(@process_count * 1000 / max(@execution_time, 1), 2)}
                    </span>
                    processes / second
                  </span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </Layouts.demo>
    """
  end
end
