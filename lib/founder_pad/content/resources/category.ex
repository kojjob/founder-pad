defmodule FounderPad.Content.Category do
  use Ash.Resource,
    domain: FounderPad.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "blog_categories"
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

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    many_to_many :posts, FounderPad.Content.Post do
      through FounderPad.Content.PostCategory
      source_attribute_on_join_resource :category_id
      destination_attribute_on_join_resource :post_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :slug, :description]
      change FounderPad.Content.Changes.GenerateSlug
    end

    update :update do
      accept [:name, :slug, :description]
    end
  end

  policies do
    policy action(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:is_admin) == true)
    end
  end
end
