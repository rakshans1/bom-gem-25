defmodule Gem.Demo.PingPongMailbox.Supervisor do
  @moduledoc """
  Session-scoped supervisor for the ping-pong mailbox demo.

  It owns the pair of process workers (A and B) and relays their
  lifecycle back to the controlling LiveView.
  """
  use Supervisor

  alias Gem.Demo.PingPongMailbox.ProcessWorker

  @type start_option :: {:session_pid, pid()} | {:session_ref, binary()} | {:interval, non_neg_integer()}

  @spec start_link([start_option]) :: Supervisor.on_start()
  def start_link(opts) when is_list(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    session_pid = Keyword.fetch!(opts, :session_pid)
    session_ref = Keyword.fetch!(opts, :session_ref)
    base_interval = Keyword.get(opts, :interval, 600)

    children = [
      %{
        id: :process_a,
        start:
          {ProcessWorker, :start_link,
           [
             [
               parent: session_pid,
               session_ref: session_ref,
               key: :a,
               label: "Process A",
               interval: base_interval
             ]
           ]}
      },
      %{
        id: :process_b,
        start:
          {ProcessWorker, :start_link,
           [
             [
               parent: session_pid,
               session_ref: session_ref,
               key: :b,
               label: "Process B",
               interval: base_interval
             ]
           ]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
