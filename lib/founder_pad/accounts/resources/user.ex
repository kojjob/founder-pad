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

    attribute :preferences, :map, default: %{}, public?: true

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
      accept [:name, :avatar_url, :preferences]
    end

    update :change_password do
      require_atomic? false
      accept []

      argument :current_password, :string, allow_nil?: false, sensitive?: true
      argument :password, :string, allow_nil?: false, sensitive?: true
      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true

      validate confirm(:password, :password_confirmation)

      change fn changeset, _ctx ->
        current = Ash.Changeset.get_argument(changeset, :current_password)
        user = changeset.data

        if Bcrypt.verify_pass(current, user.hashed_password) do
          hashed = Bcrypt.hash_pwd_salt(Ash.Changeset.get_argument(changeset, :password))
          Ash.Changeset.force_change_attribute(changeset, :hashed_password, hashed)
        else
          Ash.Changeset.add_error(changeset, field: :current_password, message: "is incorrect")
        end
      end
    end

    destroy :destroy do
      primary? true
    end
  end
end
