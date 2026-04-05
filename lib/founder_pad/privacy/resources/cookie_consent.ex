defmodule FounderPad.Privacy.CookieConsent do
  use Ash.Resource,
    domain: FounderPad.Privacy,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("cookie_consents")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :consent_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :analytics, :boolean do
      default(false)
      public?(true)
    end

    attribute :marketing, :boolean do
      default(false)
      public?(true)
    end

    attribute :functional, :boolean do
      default(true)
      public?(true)
    end

    attribute :ip_address, :string do
      public?(true)
    end

    attribute :user_agent, :string do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :user, FounderPad.Accounts.User do
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :consent_id,
        :analytics,
        :marketing,
        :functional,
        :ip_address,
        :user_agent,
        :user_id
      ])
    end

    update :update do
      accept([:analytics, :marketing, :functional])
    end
  end
end
