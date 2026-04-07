defmodule FounderPad.Accounts.SocialIdentity do
  use Ash.Resource,
    domain: FounderPad.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("social_identities")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :provider, :atom do
      constraints(one_of: [:google, :github, :microsoft])
      allow_nil?(false)
      public?(true)
    end

    attribute :provider_uid, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :provider_email, :string do
      public?(true)
    end

    attribute :provider_data, :map do
      default(%{})
      public?(true)
    end

    attribute :linked_at, :utc_datetime_usec do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_provider_uid, [:provider, :provider_uid])
    identity(:unique_provider_user, [:provider, :user_id])
  end

  relationships do
    belongs_to :user, FounderPad.Accounts.User do
      allow_nil?(false)
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:provider, :provider_uid, :provider_email, :provider_data, :user_id])
      change(set_attribute(:linked_at, &DateTime.utc_now/0))
    end

    read :by_provider do
      argument(:provider, :atom, allow_nil?: false)
      argument(:provider_uid, :string, allow_nil?: false)
      filter(expr(provider == ^arg(:provider) and provider_uid == ^arg(:provider_uid)))
    end

    read :by_user do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id)))
    end
  end
end
