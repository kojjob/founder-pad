defmodule LinkHub.Webhooks.OutboundWebhook do
  @moduledoc "Ash resource representing an outbound webhook configuration."
  use Ash.Resource,
    domain: LinkHub.Webhooks,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("outbound_webhooks")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :url, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :secret, :string do
      allow_nil?(false)
      sensitive?(true)
      public?(true)
    end

    attribute :events, {:array, :string} do
      default([])
      allow_nil?(false)
      public?(true)
    end

    attribute(:active, :boolean, default: true, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :workspace, LinkHub.Accounts.Workspace do
      allow_nil?(false)
      public?(true)
    end

    has_many :deliveries, LinkHub.Webhooks.WebhookDelivery do
      destination_attribute(:webhook_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:url, :secret, :events, :active, :description, :metadata])
      argument(:workspace_id, :uuid, allow_nil?: false)
      change(manage_relationship(:workspace_id, :workspace, type: :append))
    end

    update :update do
      accept([:url, :events, :active, :description])
    end

    update :rotate_secret do
      accept([:secret])
    end
  end
end
