defmodule FounderPad.Accounts.User do
  use Ash.Resource,
    domain: FounderPad.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "users"
    repo FounderPad.Repo
  end

  authentication do
    tokens do
      enabled? true
      token_resource FounderPad.Accounts.Token
      require_token_presence_for_authentication? true

      signing_secret fn _, _ ->
        Application.fetch_env(:founder_pad, :token_signing_secret)
      end
    end

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
      end

      magic_link do
        identity_field :email
        require_interaction? true

        sender FounderPad.Accounts.Senders.MagicLinkSender
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? true
      sensitive? true
    end

    attribute :name, :string, public?: true

    attribute :avatar_url, :string, public?: true

    attribute :confirmed_at, :utc_datetime_usec, public?: true

    timestamps()
  end

  relationships do
    has_many :memberships, FounderPad.Accounts.Membership

    many_to_many :organisations, FounderPad.Accounts.Organisation do
      through FounderPad.Accounts.Membership
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      authorize_if always()
    end
  end

  actions do
    defaults [:read]

    update :update_profile do
      accept [:name, :avatar_url]
    end

    destroy :destroy do
      primary? true
    end
  end
end
