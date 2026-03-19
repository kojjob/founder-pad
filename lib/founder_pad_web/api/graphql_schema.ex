defmodule FounderPadWeb.Api.GraphqlSchema do
  use Absinthe.Schema

  use AshGraphql,
    domains: [FounderPad.Accounts, FounderPad.Billing, FounderPad.AI]

  query do
  end

  mutation do
  end
end
