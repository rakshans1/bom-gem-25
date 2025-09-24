defmodule Gem.Demo.Supervisor do
  @moduledoc """
  Dynamic supervisor that hosts demo-specific supervision trees.

  Each LiveView session can request a fresh demo supervisor by calling
  `start_tree/1`, which keeps the root application supervision tree tidy
  while letting demos manage their own lifecycle.
  """
  use DynamicSupervisor

  @doc false
  def start_link(init_arg \\ []) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start a supervision tree under the demo supervisor.

  Accepts a child spec and returns the pid of the started supervisor.
  """
  @spec start_tree(Supervisor.child_spec()) :: DynamicSupervisor.on_start_child()
  def start_tree(child_spec) do
    with :ok <- ensure_started() do
      DynamicSupervisor.start_child(__MODULE__, child_spec)
    end
  end

  @doc """
  Gracefully stop a child supervision tree.
  """
  @spec stop_tree(pid()) :: :ok | {:error, term()}
  def stop_tree(pid) when is_pid(pid) do
    case DynamicSupervisor.terminate_child(__MODULE__, pid) do
      {:error, :not_found} -> :ok
      result -> result
    end
  end

  defp ensure_started do
    with :ok <- ensure_child_started(Gem.Demo.Registry) do
      ensure_child_started({__MODULE__, []})
    end
  end

  defp ensure_child_started({module, _} = spec), do: ensure_child_started(module, spec)
  defp ensure_child_started(module) when is_atom(module), do: ensure_child_started(module, module)

  defp ensure_child_started(module, spec) do
    case Process.whereis(module) do
      nil ->
        case Supervisor.start_child(Gem.Supervisor, spec) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, :already_present} -> :ok
          {:error, {:already_present, _pid}} -> :ok
          other -> other
        end

      _pid ->
        :ok
    end
  end
end
