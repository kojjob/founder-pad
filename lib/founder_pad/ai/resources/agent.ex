defmodule FounderPad.AI.Agent do
  use Ash.Resource,
    domain: FounderPad.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "agents"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string, public?: true

    attribute :system_prompt, :string do
      allow_nil? false
      default "You are a helpful assistant."
      public? true
    end

    attribute :model, :string do
      allow_nil? false
      default "claude-sonnet-4-20250514"
      public? true
    end

    attribute :provider, :atom do
      constraints one_of: [:anthropic, :openai]
      default :anthropic
      allow_nil? false
      public? true
    end

    attribute :tools, {:array, :map} do
      default []
      public? true
    end

    attribute :temperature, :float, default: 0.7, public?: true
    attribute :max_tokens, :integer, default: 4096, public?: true
    attribute :active, :boolean, default: true, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organisation, FounderPad.Accounts.Organisation do
      allow_nil? false
      public? true
    end

    has_many :conversations, FounderPad.AI.Conversation
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name, :description, :system_prompt, :model, :provider,
        :tools, :temperature, :max_tokens, :active
      ]

      argument :organisation_id, :uuid, allow_nil?: false
      change manage_relationship(:organisation_id, :organisation, type: :append)
    end

    update :update do
      accept [
        :name, :description, :system_prompt, :model, :provider,
        :tools, :temperature, :max_tokens, :active
      ]
    end
  end
end
