defmodule FounderPad.HelpCenter.Category do
  use Ash.Resource,
    domain: FounderPad.HelpCenter,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "help_categories"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :icon, :string do
      public? true
      default "help"
    end

    attribute :position, :integer do
      default 0
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    has_many :articles, FounderPad.HelpCenter.Article
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :slug, :description, :icon, :position]
      change FounderPad.Content.Changes.GenerateSlug
    end

    update :update do
      accept [:name, :slug, :description, :icon, :position]
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
