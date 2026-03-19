defmodule FounderPadWeb.Api.JsonApiRouter do
  use AshJsonApi.Router,
    domains: [FounderPad.Accounts, FounderPad.Billing, FounderPad.AI],
    open_api: "/open_api"
end
