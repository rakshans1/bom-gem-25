defmodule GemWeb.StatusController do
  use GemWeb, :controller

  def index(conn, _params) do
    {total_wall_clock_ms, _} = :erlang.statistics(:wall_clock)
    uptime_seconds = div(total_wall_clock_ms, 1000)

    json(conn, %{
      status: "ok",
      timestamp: DateTime.to_iso8601(DateTime.utc_now()),
      uptime_seconds: uptime_seconds
    })
  end
end
