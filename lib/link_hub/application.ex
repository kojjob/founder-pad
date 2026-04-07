defmodule LinkHub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LinkHubWeb.Telemetry,
      LinkHub.Repo,
      {DNSCluster, query: Application.get_env(:link_hub, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LinkHub.PubSub},
      {Finch, name: LinkHub.Finch},
      {Oban, Application.fetch_env!(:link_hub, Oban)},
      # Rate limiting (Hammer ETS backend)
      {LinkHub.RateLimit, clean_period: :timer.minutes(10)},
      # Presence tracking for real-time user status
      LinkHubWeb.Presence,
      # Start to serve requests, typically the last entry
      LinkHubWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LinkHub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LinkHubWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
