defmodule LinkHub.Media.ShareLink do
  @moduledoc """
  Shareable file links with optional expiry, password protection,
  and download tracking.
  """
  use Ash.Resource,
    domain: LinkHub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("share_links")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :token, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :password_hash, :string do
      public?(false)
    end

    attribute :expires_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :max_downloads, :integer do
      public?(true)
    end

    attribute :download_count, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute :active, :boolean do
      allow_nil?(false)
      default(true)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :stored_file, LinkHub.Media.StoredFile do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :created_by, LinkHub.Accounts.User do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_token, [:token])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:expires_at, :max_downloads, :password_hash])

      argument(:stored_file_id, :uuid, allow_nil?: false)
      argument(:created_by_id, :uuid, allow_nil?: false)

      change(manage_relationship(:stored_file_id, :stored_file, type: :append))
      change(manage_relationship(:created_by_id, :created_by, type: :append))

      change(fn changeset, _context ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :token,
          :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
        )
      end)
    end

    update :record_download do
      accept([])
      change(atomic_update(:download_count, expr(download_count + 1)))
    end

    update :deactivate do
      accept([])
      change(set_attribute(:active, false))
    end

    read :get_by_token do
      argument(:token, :string, allow_nil?: false)
      filter(expr(token == ^arg(:token) and active == true))
      prepare(build(load: [:stored_file]))
    end

    read :list_expired do
      filter(
        expr(
          active == true and
            not is_nil(expires_at) and
            expires_at < now()
        )
      )
    end
  end
end
