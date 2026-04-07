defmodule LinkHub.Accounts.Workspace do
  @moduledoc "Ash resource representing a workspace (organization)."
  use Ash.Resource,
    domain: LinkHub.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("workspaces")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute(:logo_url, :string, public?: true)

    attribute(:billing_email, :string, public?: true)

    timestamps()
  end

  relationships do
    has_many(:memberships, LinkHub.Accounts.Membership)

    many_to_many :users, LinkHub.Accounts.User do
      through(LinkHub.Accounts.Membership)
    end
  end

  identities do
    identity(:unique_slug, [:slug])
  end

  policies do
    policy action_type(:read) do
      authorize_if(always())
    end

    policy action_type(:create) do
      authorize_if(always())
    end

    policy action_type([:update, :destroy]) do
      authorize_if(relates_to_actor_via([:memberships, :user]))
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:name, :billing_email, :logo_url])

      change(fn changeset, _ctx ->
        case Ash.Changeset.get_attribute(changeset, :name) do
          nil ->
            changeset

          name ->
            slug =
              name
              |> String.downcase()
              |> String.replace(~r/[^a-z0-9]+/, "-")
              |> String.trim("-")

            Ash.Changeset.change_attribute(changeset, :slug, slug)
        end
      end)
    end

    update :update do
      accept([:name, :billing_email, :logo_url])
    end

    destroy :destroy do
      primary?(true)
    end
  end
end
