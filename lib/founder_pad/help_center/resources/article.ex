defmodule FounderPad.HelpCenter.Article do
  use Ash.Resource,
    domain: FounderPad.HelpCenter,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("help_articles")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 100_000)
    end

    attribute :excerpt, :string do
      public?(true)
    end

    attribute :help_context_key, :string do
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:draft, :published, :archived])
      default(:draft)
      allow_nil?(false)
      public?(true)
    end

    attribute :position, :integer do
      default(0)
      public?(true)
    end

    attribute :published_at, :utc_datetime_usec do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_slug_per_category, [:category_id, :slug])
  end

  relationships do
    belongs_to :category, FounderPad.HelpCenter.Category do
      allow_nil?(false)
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :title,
        :slug,
        :body,
        :excerpt,
        :help_context_key,
        :status,
        :position,
        :category_id
      ])

      change(FounderPad.Content.Changes.GenerateSlug)
    end

    update :update do
      accept([:title, :slug, :body, :excerpt, :help_context_key, :status, :position])
    end

    update :publish do
      change(set_attribute(:status, :published))
      change(set_attribute(:published_at, &DateTime.utc_now/0))
    end

    read :published do
      filter(expr(status == :published))
      prepare(build(sort: [position: :asc]))
    end

    read :by_category do
      argument(:category_id, :uuid, allow_nil?: false)
      filter(expr(category_id == ^arg(:category_id) and status == :published))
      prepare(build(sort: [position: :asc]))
    end

    read :search do
      argument(:query, :string, allow_nil?: false)
      filter(expr(status == :published))

      prepare(fn query, _context ->
        require Ash.Query
        search_term = Ash.Query.get_argument(query, :query)

        query
        |> Ash.Query.filter(
          fragment(
            "to_tsvector('english', coalesce(?, '') || ' ' || coalesce(?, '') || ' ' || coalesce(?, '')) @@ plainto_tsquery('english', ?)",
            title,
            excerpt,
            body,
            ^search_term
          )
        )
        |> Ash.Query.load([:category])
      end)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if(always())
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if(expr(^actor(:is_admin) == true))
    end
  end
end
