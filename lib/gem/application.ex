defmodule Gem.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GemWeb.Telemetry,
      Gem.Repo,
      {Ecto.Migrator, repos: Application.fetch_env!(:gem, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:gem, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Gem.PubSub},
      Gem.Demo.Registry,
      Gem.Demo.Supervisor,
      # Start a worker by calling: Gem.Worker.start_link(arg)
      # {Gem.Worker, arg},
      # Start to serve requests, typically the last entry
      GemWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Gem.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GemWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations? do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
