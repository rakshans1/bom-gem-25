defmodule Gem.Demo do
  @moduledoc """
  Broadcast controls for Gem demo experiences.

  Provides helper functions to pause and resume demos via Phoenix PubSub.
  """

  @topic "demo:ping-pong"

  @doc """
  Returns the PubSub topic used for demo control messages.
  """
  @spec pubsub_topic() :: String.t()
  def pubsub_topic, do: @topic

  @doc """
  Broadcasts a pause command to all subscribers.
  """
  @spec pause() :: :ok
  def pause, do: broadcast(:pause)

  @doc """
  Broadcasts a play command to all subscribers.
  """
  @spec play() :: :ok
  def play, do: broadcast(:play)

  defp broadcast(action) when action in [:pause, :play] do
    Phoenix.PubSub.broadcast(Gem.PubSub, @topic, {:demo_control, action})
  end
end
