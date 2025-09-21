defmodule GemWeb.PageController do
  use GemWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
