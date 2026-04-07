defmodule FounderPad.Accounts.Token do
  use Ash.Resource,
    domain: FounderPad.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("tokens")
    repo(FounderPad.Repo)
  end

  actions do
    defaults([:read, :destroy])
  end
end
