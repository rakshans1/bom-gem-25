defmodule Gem.Demo.FaultTolerance.Worker do
  @moduledoc """
  Macro that injects shared behaviour for demo workers.

  Each worker registers itself in the shared registry, notifies the
  controlling LiveView when it boots, and exposes a consistent API for
  triggering crash scenarios.
  """

  @type crash_type :: :normal | :runtime | :timeout | :brutal_kill

  defmacro __using__(opts) do
    key = Keyword.fetch!(opts, :key)
    name = Keyword.fetch!(opts, :name)
    color = Keyword.fetch!(opts, :color)
    restart = Keyword.fetch!(opts, :restart)

    quote bind_quoted: [key: key, name: name, color: color, restart: restart] do
      use GenServer

      @worker_metadata %{key: key, name: name, color: color, restart: restart}

      @type state :: %{
              parent: pid(),
              session_ref: binary(),
              metadata: map()
            }

      def metadata, do: @worker_metadata

      def start_link(opts) do
        parent = Keyword.fetch!(opts, :parent)
        session_ref = Keyword.fetch!(opts, :session_ref)

        GenServer.start_link(__MODULE__, %{parent: parent, session_ref: session_ref}, [])
      end

      @impl true
      def init(state) do
        Registry.register(Gem.Demo.Registry, {state.session_ref, @worker_metadata.key}, nil)
        send(state.parent, {:worker_started, state.session_ref, @worker_metadata, self()})
        {:ok, Map.put(state, :metadata, @worker_metadata)}
      end

      @impl true
      def handle_cast({:crash, :normal}, state), do: {:stop, :normal, state}

      def handle_cast({:crash, :runtime}, state) do
        raise(RuntimeError, message(@worker_metadata.name))
      end

      def handle_cast({:crash, :timeout}, state) do
        Process.exit(self(), :timeout)
        {:noreply, state}
      end

      def handle_cast({:crash, :brutal_kill}, state) do
        Process.exit(self(), :kill)
        {:noreply, state}
      end

      @impl true
      def handle_info(:simulate_work, state), do: {:noreply, state}

      defp message(name), do: "#{name} encountered a simulated runtime failure"
    end
  end
end
