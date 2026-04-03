defmodule FounderPad.ApiKeys.ApiKeyUsage do
  use Ash.Resource,
    domain: FounderPad.ApiKeys,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "api_key_usage"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :endpoint, :string do
      public? true
    end

    attribute :method, :string do
      public? true
    end

    attribute :status_code, :integer do
      public? true
    end

    attribute :response_time_ms, :integer do
      public? true
    end

    attribute :ip_address, :string do
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :api_key, FounderPad.ApiKeys.ApiKey do
      allow_nil? false
      attribute_type :uuid
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:endpoint, :method, :status_code, :response_time_ms, :ip_address, :api_key_id]
    end

    read :by_key do
      argument :api_key_id, :uuid, allow_nil?: false
      filter expr(api_key_id == ^arg(:api_key_id))
      prepare build(sort: [inserted_at: :desc])
    end
  end
end
