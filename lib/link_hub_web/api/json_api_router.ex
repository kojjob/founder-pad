defmodule LinkHubWeb.Api.JsonApiRouter do
  @moduledoc "JSON:API router for Ash-powered REST endpoints."
  use AshJsonApi.Router,
    domains: [LinkHub.Accounts, LinkHub.Billing, LinkHub.AI],
    open_api: "/open_api"
end
