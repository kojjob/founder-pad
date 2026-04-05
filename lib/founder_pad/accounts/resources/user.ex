defmodule FounderPad.Accounts.User do
  use Ash.Resource,
    domain: FounderPad.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("users")
    repo(FounderPad.Repo)
  end

  authentication do
    tokens do
      enabled?(true)
      token_resource(FounderPad.Accounts.Token)
      require_token_presence_for_authentication?(true)

      signing_secret(fn _, _ ->
        Application.fetch_env(:founder_pad, :token_signing_secret)
      end)
    end

    strategies do
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
      end

      magic_link do
        identity_field(:email)
        require_interaction?(true)

        sender(FounderPad.Accounts.Senders.MagicLinkSender)
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :email, :ci_string do
      allow_nil?(false)
      public?(true)
    end

    attribute :hashed_password, :string do
      allow_nil?(true)
      sensitive?(true)
    end

    attribute(:name, :string, public?: true)

    attribute(:avatar_url, :string, public?: true)

    attribute(:preferences, :map, default: %{}, public?: true)

    attribute(:confirmed_at, :utc_datetime_usec, public?: true)

    attribute :is_admin, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
    end

    attribute :suspended_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :email_preferences, :map do
      default(%{
        "marketing" => true,
        "product_updates" => true,
        "weekly_digest" => true,
        "billing" => true,
        "team" => true
      })

      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many(:memberships, FounderPad.Accounts.Membership)
    has_many(:social_identities, FounderPad.Accounts.SocialIdentity)

    many_to_many :organisations, FounderPad.Accounts.Organisation do
      through(FounderPad.Accounts.Membership)
    end
  end

  identities do
    identity(:unique_email, [:email])
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if(always())
    end

    # TODO: Tighten update/destroy policies once all call sites pass actor:
    # policy action_type([:update, :destroy]) do
    #   authorize_if expr(id == ^actor(:id))
    # end
    policy action([:suspend, :unsuspend, :list_all, :toggle_admin]) do
      authorize_if(expr(^actor(:is_admin) == true))
    end

    policy always() do
      authorize_if(always())
    end
  end

  changes do
    change(FounderPad.Accounts.Changes.SendWelcomeEmail,
      on: [:create],
      where: [action_is(:register_with_password)]
    )
  end

  actions do
    defaults([:read])

    update :update_profile do
      accept([:name, :avatar_url, :preferences])
    end

    update :change_password do
      require_atomic?(false)
      accept([])

      argument(:current_password, :string, allow_nil?: false, sensitive?: true)
      argument(:password, :string, allow_nil?: false, sensitive?: true)
      argument(:password_confirmation, :string, allow_nil?: false, sensitive?: true)

      validate(confirm(:password, :password_confirmation))

      change(fn changeset, _ctx ->
        current = Ash.Changeset.get_argument(changeset, :current_password)
        user = changeset.data

        if Bcrypt.verify_pass(current, user.hashed_password) do
          hashed = Bcrypt.hash_pwd_salt(Ash.Changeset.get_argument(changeset, :password))
          Ash.Changeset.force_change_attribute(changeset, :hashed_password, hashed)
        else
          Ash.Changeset.add_error(changeset, field: :current_password, message: "is incorrect")
        end
      end)
    end

    destroy :destroy do
      primary?(true)
    end

    update :suspend do
      accept([])
      change(set_attribute(:suspended_at, &DateTime.utc_now/0))
    end

    update :unsuspend do
      accept([])
      change(set_attribute(:suspended_at, nil))
    end

    update :toggle_admin do
      require_atomic?(false)
      accept([])

      change(fn changeset, _ctx ->
        current = changeset.data.is_admin
        Ash.Changeset.force_change_attribute(changeset, :is_admin, !current)
      end)
    end

    update :update_email_preferences do
      accept([:email_preferences])
    end

    read :list_all do
      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
