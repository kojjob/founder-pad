defmodule LinkHub.Webhooks.WebhookDelivery do
  @moduledoc "Ash resource representing a webhook delivery attempt."
  use Ash.Resource,
    domain: LinkHub.Webhooks,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("webhook_deliveries")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:event_type, :string, allow_nil?: false, public?: true)
    attribute(:payload, :map, default: %{}, public?: true)
    attribute(:response_status, :integer, public?: true)
    attribute(:response_body, :string, public?: true)
    attribute(:error, :string, public?: true)
    attribute(:attempts, :integer, default: 0, public?: true)

    attribute :status, :atom do
      constraints(one_of: [:pending, :delivered, :failed])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute(:delivered_at, :utc_datetime, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :webhook, LinkHub.Webhooks.OutboundWebhook do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:event_type, :payload, :status])
      argument(:webhook_id, :uuid, allow_nil?: false)
      change(manage_relationship(:webhook_id, :webhook, type: :append))
    end

    update :mark_delivered do
      accept([:response_status, :response_body, :attempts])
      change(set_attribute(:status, :delivered))
      change(set_attribute(:delivered_at, &DateTime.utc_now/0))
    end

    update :mark_failed do
      accept([:error, :response_status, :response_body, :attempts])
      change(set_attribute(:status, :failed))
    end
  end
end
