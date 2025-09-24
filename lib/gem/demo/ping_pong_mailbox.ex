defmodule Gem.Demo.PingPongMailbox do
  @moduledoc """
  Entry point for the ping-pong mailbox demo runtime helpers.

  Provides convenience functions to start and stop the session-scoped
  supervision tree as well as delegate actions to individual workers.
  """

  alias Gem.Demo.PingPongMailbox.Message
  alias Gem.Demo.PingPongMailbox.ProcessWorker
  alias Gem.Demo.PingPongMailbox.Supervisor
  alias Gem.Demo.Supervisor, as: DemoSupervisor

  @type session_ref :: binary()
  @type process_key :: ProcessWorker.process_key()

  @doc """
  Start a session-scoped supervision tree that hosts the two process
  workers. Returns `{:ok, pid}` on success.
  """
  @spec start_tree(session_ref(), pid(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_tree(session_ref, session_pid, opts \\ []) do
    child_spec = %{
      id: {Supervisor, session_ref},
      start: {Supervisor, :start_link, [[session_pid: session_pid, session_ref: session_ref] ++ opts]},
      restart: :temporary,
      type: :supervisor
    }

    DemoSupervisor.start_tree(child_spec)
  end

  @doc """
  Stop the supervision tree for the given session pid.
  """
  @spec stop_tree(pid()) :: :ok | {:error, term()}
  def stop_tree(tree_pid) when is_pid(tree_pid) do
    DemoSupervisor.stop_tree(tree_pid)
  end

  @doc """
  Enqueue a message for the given worker.
  """
  @spec enqueue(pid(), Message.t()) :: :ok
  def enqueue(worker_pid, %Message{} = message) when is_pid(worker_pid) do
    ProcessWorker.enqueue(worker_pid, message)
  end

  @doc """
  Adjust the processing interval (in milliseconds) for the worker.
  """
  @spec set_interval(pid(), non_neg_integer()) :: :ok
  def set_interval(worker_pid, interval) when is_pid(worker_pid) do
    ProcessWorker.set_interval(worker_pid, interval)
  end

  @doc """
  Pause message processing for the worker.
  """
  @spec pause(pid()) :: :ok
  def pause(worker_pid) when is_pid(worker_pid) do
    ProcessWorker.pause(worker_pid)
  end

  @doc """
  Resume message processing for the worker.
  """
  @spec resume(pid()) :: :ok
  def resume(worker_pid) when is_pid(worker_pid) do
    ProcessWorker.resume(worker_pid)
  end

  @doc """
  Reset worker queue and state.
  """
  @spec reset(pid()) :: :ok
  def reset(worker_pid) when is_pid(worker_pid) do
    ProcessWorker.reset(worker_pid)
  end
end
