defmodule FounderPad.Notifications.PushSubscription do
  use Ash.Resource,
    domain: FounderPad.Notifications,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "push_subscriptions"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      constraints one_of: [:fcm, :web_push]
      allow_nil? false
      public? true
    end

    attribute :token, :string do
      allow_nil? false
      public? true
      constraints max_length: 10_000
    end

    attribute :device_name, :string do
      public? true
    end

    attribute :active, :boolean do
      default true
      allow_nil? false
      public? true
    end

    attribute :last_used_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_user_token, [:user_id, :token]
  end

  relationships do
    belongs_to :user, FounderPad.Accounts.User do
      allow_nil? false
      attribute_type :uuid
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:type, :token, :device_name, :user_id]
    end

    update :deactivate do
      accept []
      change set_attribute(:active, false)
    end

    update :touch do
      accept []
      change set_attribute(:last_used_at, &DateTime.utc_now/0)
    end

    read :active_for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and active == true)
    end
  end
end
