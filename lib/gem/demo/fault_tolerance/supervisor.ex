defmodule Gem.Demo.FaultTolerance.Supervisor do
  @moduledoc """
  Session-scoped supervisor for the fault-tolerance demo.

  It starts the three worker processes with their respective restart
  strategies and relays crash information back to the controlling
  LiveView via messages.
  """
  use Supervisor

  alias Gem.Demo.FaultTolerance.APIWorker
  alias Gem.Demo.FaultTolerance.CacheWorker
  alias Gem.Demo.FaultTolerance.DBWorker

  @type start_option :: {:session_pid, pid()} | {:session_ref, binary()} | {:strategy, Supervisor.strategy()}

  @spec start_link([start_option]) :: Supervisor.on_start()
  def start_link(opts) when is_list(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    session_pid = Keyword.fetch!(opts, :session_pid)
    session_ref = Keyword.fetch!(opts, :session_ref)
    strategy = Keyword.fetch!(opts, :strategy)

    base_child_opts = [parent: session_pid, session_ref: session_ref]

    children = [
      %{
        id: :db_worker,
        start: {DBWorker, :start_link, [base_child_opts]},
        restart: :permanent,
        type: :worker,
        shutdown: 5_000
      },
      %{
        id: :cache_worker,
        start: {CacheWorker, :start_link, [base_child_opts]},
        restart: :temporary,
        type: :worker,
        shutdown: 5_000
      },
      %{
        id: :api_worker,
        start: {APIWorker, :start_link, [base_child_opts]},
        restart: :transient,
        type: :worker,
        shutdown: 5_000
      }
    ]

    Supervisor.init(children, strategy: strategy)
  end
end
