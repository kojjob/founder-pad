defmodule FounderPad.Content.Post do
  use Ash.Resource,
    domain: FounderPad.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "blog_posts"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :body, :string do
      public? true
      constraints max_length: 500_000
    end

    attribute :excerpt, :string do
      public? true
      constraints max_length: 500
    end

    attribute :featured_image_url, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :scheduled, :archived]
      default :draft
      allow_nil? false
      public? true
    end

    attribute :published_at, :utc_datetime_usec do
      public? true
    end

    attribute :scheduled_at, :utc_datetime_usec do
      public? true
    end

    attribute :reading_time_minutes, :integer do
      default 1
      public? true
    end

    attribute :meta_title, :string do
      public? true
      constraints max_length: 70
    end

    attribute :meta_description, :string do
      public? true
      constraints max_length: 160
    end

    attribute :og_image_url, :string do
      public? true
    end

    attribute :canonical_url, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    belongs_to :author, FounderPad.Accounts.User do
      allow_nil? false
      attribute_type :uuid
    end

    many_to_many :categories, FounderPad.Content.Category do
      through FounderPad.Content.PostCategory
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :category_id
    end

    many_to_many :tags, FounderPad.Content.Tag do
      through FounderPad.Content.PostTag
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :title, :slug, :body, :excerpt, :featured_image_url, :status,
        :published_at, :scheduled_at, :meta_title, :meta_description,
        :og_image_url, :canonical_url, :author_id
      ]

      change FounderPad.Content.Changes.GenerateSlug
      change FounderPad.Content.Changes.CalculateReadingTime
    end

    update :update do
      require_atomic? false

      accept [
        :title, :slug, :body, :excerpt, :featured_image_url, :status,
        :published_at, :scheduled_at, :meta_title, :meta_description,
        :og_image_url, :canonical_url
      ]

      change FounderPad.Content.Changes.CalculateReadingTime
    end

    update :publish do
      change set_attribute(:status, :published)
      change set_attribute(:published_at, &DateTime.utc_now/0)
    end

    update :schedule do
      accept [:scheduled_at]
      change set_attribute(:status, :scheduled)
    end

    update :archive do
      change set_attribute(:status, :archived)
    end

    read :published do
      filter expr(status == :published and published_at <= now())
      prepare build(sort: [published_at: :desc])
    end

    read :by_slug do
      argument :slug, :string, allow_nil?: false
      filter expr(slug == ^arg(:slug) and status == :published)
      prepare build(load: [:author, :categories, :tags])
    end

    read :scheduled_ready do
      filter expr(status == :scheduled and scheduled_at <= now())
    end
  end

  policies do
    policy action([:published, :by_slug]) do
      authorize_if always()
    end

    policy action(:scheduled_ready) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:is_admin) == true)
    end

    policy action(:read) do
      authorize_if expr(^actor(:is_admin) == true)
    end
  end
end
