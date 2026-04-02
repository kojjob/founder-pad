defmodule FounderPad.Content.ChangelogEntry do
  use Ash.Resource,
    domain: FounderPad.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "changelog_entries"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :version, :string do
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :body, :string do
      public? true
      constraints max_length: 100_000
    end

    attribute :type, :atom do
      constraints one_of: [:feature, :fix, :improvement, :breaking]
      default :feature
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published]
      default :draft
      allow_nil? false
      public? true
    end

    attribute :published_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :author, FounderPad.Accounts.User do
      allow_nil? false
      attribute_type :uuid
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:version, :title, :body, :type, :status, :published_at, :author_id]
    end

    update :update do
      accept [:version, :title, :body, :type, :status]
    end

    update :publish do
      change set_attribute(:status, :published)
      change set_attribute(:published_at, &DateTime.utc_now/0)
    end

    read :published do
      filter expr(status == :published)
      prepare build(sort: [published_at: :desc])
    end
  end

  policies do
    policy action(:published) do
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
