defmodule FounderPad.System.Incident do
  use Ash.Resource,
    domain: FounderPad.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("incidents")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :description, :string do
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:investigating, :identified, :monitoring, :resolved])
      default(:investigating)
      allow_nil?(false)
      public?(true)
    end

    attribute :severity, :atom do
      constraints(one_of: [:minor, :major, :critical])
      default(:minor)
      allow_nil?(false)
      public?(true)
    end

    attribute :affected_components, {:array, :string} do
      default([])
      public?(true)
    end

    attribute :resolved_at, :utc_datetime_usec do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:title, :description, :status, :severity, :affected_components])
    end

    update :update do
      accept([:title, :description, :status, :severity, :affected_components])
    end

    update :resolve do
      change(set_attribute(:status, :resolved))
      change(set_attribute(:resolved_at, &DateTime.utc_now/0))
    end

    read :active do
      filter(expr(status != :resolved))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :recent do
      prepare(build(sort: [inserted_at: :desc], limit: 20))
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
