defmodule LinkHub.Accounts.Membership do
  @moduledoc "Ash resource representing a user's membership in a workspace."
  use Ash.Resource,
    domain: LinkHub.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("memberships")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :role, :atom do
      constraints(one_of: [:owner, :admin, :member])
      default(:member)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :user, LinkHub.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :workspace, LinkHub.Accounts.Workspace do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_user_org, [:user_id, :workspace_id])
  end

  policies do
    policy action_type([:read, :create]) do
      authorize_if(always())
    end

    policy action_type([:update, :destroy]) do
      authorize_if(expr(user_id == ^actor(:id)))
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:role])

      argument(:user_id, :uuid, allow_nil?: false)
      argument(:workspace_id, :uuid, allow_nil?: false)

      change(manage_relationship(:user_id, :user, type: :append))
      change(manage_relationship(:workspace_id, :workspace, type: :append))
    end

    update :change_role do
      accept([:role])
    end
  end
end
