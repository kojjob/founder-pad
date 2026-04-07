defmodule LinkHub.Analytics.SearchConsoleData do
  @moduledoc "Ash resource representing Google Search Console data."
  use Ash.Resource,
    domain: LinkHub.Analytics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("search_console_data")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :keyword, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute(:page, :string, public?: true)
    attribute(:clicks, :integer, default: 0, public?: true)
    attribute(:impressions, :integer, default: 0, public?: true)

    attribute(:position, :float, public?: true)

    attribute(:ctr, :float, public?: true)

    attribute(:workspace_id, :uuid, public?: true)

    attribute :fetched_at, :utc_datetime do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :keyword,
        :page,
        :clicks,
        :impressions,
        :position,
        :ctr,
        :workspace_id,
        :fetched_at
      ])
    end

    read :by_workspace do
      argument(:workspace_id, :uuid, allow_nil?: false)
      filter(expr(workspace_id == ^arg(:workspace_id)))
    end
  end
end
