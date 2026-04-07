defmodule LinkHubWeb.Api.GraphqlSchema do
  @moduledoc "Absinthe GraphQL schema for the LinkHub API."
  use Absinthe.Schema

  use AshGraphql,
    domains: [LinkHub.Accounts, LinkHub.Billing, LinkHub.AI]

  query do
  end

  mutation do
  end
end
