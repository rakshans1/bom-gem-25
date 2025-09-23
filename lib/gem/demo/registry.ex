defmodule Gem.Demo.Registry do
  @moduledoc """
  Registry for demo processes, grouped by session and worker key.
  """

  @spec child_spec([]) :: Supervisor.child_spec()
  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end
end
