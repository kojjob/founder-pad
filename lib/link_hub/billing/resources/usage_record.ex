defmodule LinkHub.Billing.UsageRecord do
  @moduledoc "Ash resource representing a metered usage record."
  use Ash.Resource,
    domain: LinkHub.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("usage_records")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :event_type, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :quantity, :integer do
      default(1)
      allow_nil?(false)
      public?(true)
    end

    attribute(:metadata, :map, default: %{}, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :workspace, LinkHub.Accounts.Workspace do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:event_type, :quantity, :metadata])
      argument(:workspace_id, :uuid, allow_nil?: false)
      change(manage_relationship(:workspace_id, :workspace, type: :append))
    end

    read :by_workspace do
      argument(:workspace_id, :uuid, allow_nil?: false)
      filter(expr(workspace_id == ^arg(:workspace_id)))
    end
  end
end
