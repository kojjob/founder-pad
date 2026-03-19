defmodule FounderPad.Billing.UsageRecord do
  use Ash.Resource,
    domain: FounderPad.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "usage_records"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :event_type, :string do
      allow_nil? false
      public? true
    end

    attribute :quantity, :integer do
      default 1
      allow_nil? false
      public? true
    end

    attribute :metadata, :map, default: %{}, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organisation, FounderPad.Accounts.Organisation do
      allow_nil? false
      public? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:event_type, :quantity, :metadata]
      argument :organisation_id, :uuid, allow_nil?: false
      change manage_relationship(:organisation_id, :organisation, type: :append)
    end

    read :by_organisation do
      argument :organisation_id, :uuid, allow_nil?: false
      filter expr(organisation_id == ^arg(:organisation_id))
    end
  end
end
