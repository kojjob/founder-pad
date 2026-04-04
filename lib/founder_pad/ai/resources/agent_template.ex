defmodule FounderPad.AI.AgentTemplate do
  use Ash.Resource,
    domain: FounderPad.AI,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "agent_templates"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
    attribute :category, :string, public?: true
    attribute :system_prompt, :string, public?: true, constraints: [max_length: 50_000]
    attribute :model, :string, default: "claude-sonnet-4-20250514", public?: true
    attribute :provider, :atom, constraints: [one_of: [:anthropic, :openai]], default: :anthropic, public?: true
    attribute :icon, :string, default: "smart_toy", public?: true
    attribute :featured, :boolean, default: false, public?: true
    attribute :use_count, :integer, default: 0, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :category, :system_prompt, :model, :provider, :icon, :featured]
    end

    update :update do
      accept [:name, :description, :category, :system_prompt, :model, :provider, :icon, :featured]
    end

    update :increment_use_count do
      change fn changeset, _ ->
        current = Ash.Changeset.get_attribute(changeset, :use_count) || 0
        Ash.Changeset.force_change_attribute(changeset, :use_count, current + 1)
      end

      require_atomic? false
    end

    read :featured do
      filter expr(featured == true)
      prepare build(sort: [use_count: :desc])
    end

    read :by_category do
      argument :category, :string, allow_nil?: false
      filter expr(category == ^arg(:category))
      prepare build(sort: [use_count: :desc])
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:is_admin) == true)
    end
  end
end
