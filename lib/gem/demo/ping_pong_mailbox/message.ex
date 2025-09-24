defmodule Gem.Demo.PingPongMailbox.Message do
  @moduledoc """
  Envelope structure used by the ping-pong mailbox demo.

  Each message captures metadata needed for visualization such as
  the originating and destination processes, payload label, and the
  color that should be rendered in the LiveView.
  """

  @type type :: :ping | :pong | :data | :task | :result | :gossip | :system

  @enforce_keys [:id, :type, :label, :from, :to, :color, :inserted_at]
  defstruct [:id, :type, :label, :from, :to, :color, :payload, :inserted_at]

  @type t :: %__MODULE__{
          id: String.t(),
          type: type(),
          label: String.t(),
          from: atom(),
          to: atom(),
          color: String.t(),
          payload: term(),
          inserted_at: integer()
        }

  @colors %{
    ping: "#84a0c6",
    pong: "#89b8c2",
    data: "#b4be82",
    task: "#e2a478",
    result: "#c6c8d1",
    gossip: "#9d79d6",
    system: "#6b7089"
  }

  @labels %{
    ping: "ping",
    pong: "pong",
    data: "data",
    task: "task",
    result: "result",
    gossip: "gossip",
    system: "system"
  }

  @doc """
  Create a new message envelope.
  """
  @spec new(type(), keyword()) :: t()
  def new(type, opts \\ []) when is_atom(type) do
    color = Keyword.get(opts, :color, Map.fetch!(@colors, type))
    payload = Keyword.get(opts, :payload)
    label = Keyword.get(opts, :label, default_label(type, payload))

    %__MODULE__{
      id: Keyword.get(opts, :id, unique_id()),
      type: type,
      label: label,
      from: Keyword.get(opts, :from, :system),
      to: Keyword.get(opts, :to, :system),
      color: color,
      payload: payload,
      inserted_at: Keyword.get(opts, :inserted_at, System.system_time(:millisecond))
    }
  end

  defp default_label(type, payload) do
    case {type, payload} do
      {_, nil} -> Map.fetch!(@labels, type)
      {:data, n} when is_integer(n) -> "data(#{n})"
      {:task, n} when is_integer(n) -> "task(#{n})"
      {:result, n} when is_integer(n) -> "result(#{n})"
      _ -> Map.fetch!(@labels, type)
    end
  end

  defp unique_id do
    "msg-" <> Integer.to_string(System.unique_integer([:positive]))
  end
end
