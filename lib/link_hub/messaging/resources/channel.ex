defmodule LinkHub.Messaging.Channel do
  @moduledoc "Ash resource representing a messaging channel within a workspace."
  use Ash.Resource,
    domain: LinkHub.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("channels")
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

    attribute(:description, :string, public?: true)
    attribute(:topic, :string, public?: true)

    attribute :visibility, :atom do
      constraints(one_of: [:public, :private])
      default(:public)
      allow_nil?(false)
      public?(true)
    end

    attribute(:archived_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :workspace, LinkHub.Accounts.Workspace do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :created_by, LinkHub.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    has_many(:messages, LinkHub.Messaging.Message)
    has_many(:memberships, LinkHub.Messaging.ChannelMembership)

    many_to_many :members, LinkHub.Accounts.User do
      through(LinkHub.Messaging.ChannelMembership)
    end
  end

  identities do
    identity(:unique_slug_per_workspace, [:workspace_id, :slug])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :description, :visibility, :workspace_id])

      argument(:created_by_id, :uuid, allow_nil?: false)

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

      change(manage_relationship(:created_by_id, :created_by, type: :append))
    end

    read :list_by_workspace do
      argument(:workspace_id, :uuid, allow_nil?: false)

      filter(expr(workspace_id == ^arg(:workspace_id) and is_nil(archived_at)))

      prepare(build(sort: [name: :asc]))
    end

    update :update do
      accept([:name, :description, :topic])
    end

    update :archive do
      change(set_attribute(:archived_at, &DateTime.utc_now/0))
    end
  end
end
