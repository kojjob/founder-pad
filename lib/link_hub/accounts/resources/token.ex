defmodule LinkHub.Accounts.Token do
  @moduledoc "Ash resource representing an authentication token."
  use Ash.Resource,
    domain: LinkHub.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("tokens")
    repo(LinkHub.Repo)
  end

  actions do
    defaults([:read, :destroy])
  end
end
