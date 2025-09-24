defmodule Gem.Demo.PingPongMailbox.ProcessWorker do
  @moduledoc """
  Stateful worker that simulates a BEAM process draining its mailbox
  one message at a time. It forwards lifecycle events back to the
  controlling LiveView so the UI can update mailboxes, code snippets,
  and metrics in real time.
  """
  use GenServer

  alias Gem.Demo.PingPongMailbox.Message

  @type process_key :: :a | :b

  @type start_option ::
          {:parent, pid()}
          | {:session_ref, binary()}
          | {:key, process_key()}
          | {:interval, non_neg_integer()}
          | {:label, String.t()}

  @typedoc "Internal state tracked by the worker"
  @type state :: %{
          parent: pid(),
          session_ref: binary(),
          key: process_key(),
          label: String.t(),
          interval: non_neg_integer(),
          queue: :queue.queue(Message.t()),
          processing?: boolean(),
          current: Message.t() | nil,
          paused?: boolean()
        }

  ## Client API

  @spec start_link([start_option]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec enqueue(pid(), Message.t()) :: :ok
  def enqueue(pid, %Message{} = message) do
    GenServer.cast(pid, {:enqueue, message})
  end

  @spec set_interval(pid(), non_neg_integer()) :: :ok
  def set_interval(pid, interval) when is_integer(interval) and interval >= 0 do
    GenServer.cast(pid, {:set_interval, interval})
  end

  @spec pause(pid()) :: :ok
  def pause(pid), do: GenServer.cast(pid, :pause)

  @spec resume(pid()) :: :ok
  def resume(pid), do: GenServer.cast(pid, :resume)

  @spec reset(pid()) :: :ok
  def reset(pid), do: GenServer.cast(pid, :reset)

  ## Server callbacks

  @impl true
  def init(opts) do
    state = %{
      parent: Keyword.fetch!(opts, :parent),
      session_ref: Keyword.fetch!(opts, :session_ref),
      key: Keyword.fetch!(opts, :key),
      label: Keyword.get(opts, :label, "Process"),
      interval: Keyword.get(opts, :interval, 600),
      queue: :queue.new(),
      processing?: false,
      current: nil,
      paused?: false
    }

    send(state.parent, {:ppm_worker_started, state.session_ref, state.key, self()})

    {:ok, state}
  end

  @impl true
  def handle_cast({:enqueue, message}, state) do
    new_state =
      state
      |> Map.update!(:queue, &:queue.in(message, &1))
      |> maybe_start_processing()

    {:noreply, new_state}
  end

  def handle_cast({:set_interval, interval}, state) do
    {:noreply, %{state | interval: interval}}
  end

  def handle_cast(:pause, state) do
    {:noreply, %{state | paused?: true}}
  end

  def handle_cast(:resume, state) do
    state = %{state | paused?: false}
    {:noreply, maybe_start_processing(state)}
  end

  def handle_cast(:reset, state) do
    {:noreply,
     state
     |> Map.put(:queue, :queue.new())
     |> Map.put(:processing?, false)
     |> Map.put(:current, nil)}
  end

  @impl true
  def handle_info({:complete, message_id}, %{current: %{id: message_id}} = state) do
    send(state.parent, {:ppm_processing_complete, state.session_ref, state.key, state.current})

    state =
      state
      |> Map.put(:processing?, false)
      |> Map.put(:current, nil)

    {:noreply, maybe_start_processing(state)}
  end

  def handle_info({:complete, _}, state) do
    {:noreply, state}
  end

  defp maybe_start_processing(%{processing?: true} = state), do: state
  defp maybe_start_processing(%{paused?: true} = state), do: state

  defp maybe_start_processing(state) do
    case :queue.out(state.queue) do
      {{:value, message}, rest} ->
        send(state.parent, {:ppm_processing_started, state.session_ref, state.key, message})

        Process.send_after(self(), {:complete, message.id}, state.interval)

        %{state | queue: rest, processing?: true, current: message}

      {:empty, _} ->
        state
    end
  end
end
