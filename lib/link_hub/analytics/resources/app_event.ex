defmodule LinkHub.Analytics.AppEvent do
  @moduledoc "Ash resource representing an application analytics event."
  use Ash.Resource,
    domain: LinkHub.Analytics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("app_events")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :event_name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute(:actor_id, :uuid, public?: true)
    attribute(:workspace_id, :uuid, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)

    attribute :occurred_at, :utc_datetime do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :create do
      accept([:event_name, :actor_id, :workspace_id, :metadata, :occurred_at])
    end

    read :by_workspace do
      argument(:workspace_id, :uuid, allow_nil?: false)
      filter(expr(workspace_id == ^arg(:workspace_id)))
    end

    read :by_event_name do
      argument(:event_name, :string, allow_nil?: false)
      filter(expr(event_name == ^arg(:event_name)))
    end
  end
end
