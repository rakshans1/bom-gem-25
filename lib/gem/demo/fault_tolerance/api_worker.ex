defmodule Gem.Demo.FaultTolerance.APIWorker do
  @moduledoc """
  External API client that restarts only on abnormal exits.
  """
  use Gem.Demo.FaultTolerance.Worker,
    key: :api,
    name: "API Worker",
    color: "#b4be82",
    restart: :transient
end
