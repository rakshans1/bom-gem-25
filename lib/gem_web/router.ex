defmodule GemWeb.Router do
  use GemWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GemWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GemWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/slides", SlidesController, :app
    get "/slides/*path", SlidesController, :app
    live "/demo/processes", ProcessDemoLive
    live "/demo/ping-pong", PingPongDemoLive
  end

  # Other scopes may use custom stacks.
  scope "/api", GemWeb do
    pipe_through :api

    get "/status", StatusController, :index
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:gem, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GemWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
