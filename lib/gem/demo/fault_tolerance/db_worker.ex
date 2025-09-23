defmodule Gem.Demo.FaultTolerance.DBWorker do
  @moduledoc """
  Critical worker that simulates a permanent database connection.
  """
  use Gem.Demo.FaultTolerance.Worker,
    key: :db,
    name: "DB Worker",
    color: "#84a0c6",
    restart: :permanent
end
