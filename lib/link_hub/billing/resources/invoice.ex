defmodule LinkHub.Billing.Invoice do
  @moduledoc "Ash resource representing a billing invoice."
  use Ash.Resource,
    domain: LinkHub.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("invoices")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :invoice_number, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :amount_cents, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:paid, :pending, :failed, :refunded])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :stripe_invoice_id, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :period_start, :date do
      allow_nil?(false)
      public?(true)
    end

    attribute :period_end, :date do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :workspace, LinkHub.Accounts.Workspace do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :invoice_number,
        :amount_cents,
        :status,
        :stripe_invoice_id,
        :period_start,
        :period_end
      ])

      argument(:workspace_id, :uuid, allow_nil?: false)
      change(manage_relationship(:workspace_id, :workspace, type: :append))
    end
  end
end
