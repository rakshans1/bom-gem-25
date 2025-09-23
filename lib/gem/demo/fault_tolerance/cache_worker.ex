defmodule Gem.Demo.FaultTolerance.CacheWorker do
  @moduledoc """
  Optional cache service that uses the temporary restart strategy.
  """
  use Gem.Demo.FaultTolerance.Worker,
    key: :cache,
    name: "Cache Worker",
    color: "#89b8c2",
    restart: :temporary
end
