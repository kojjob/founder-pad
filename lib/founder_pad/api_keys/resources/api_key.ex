defmodule FounderPad.ApiKeys.ApiKey do
  use Ash.Resource,
    domain: FounderPad.ApiKeys,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("api_keys")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :key_prefix, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :key_hash, :string do
      allow_nil?(false)
    end

    attribute :scopes, {:array, :atom} do
      constraints(items: [one_of: [:read, :write, :admin]])
      default([:read])
      allow_nil?(false)
      public?(true)
    end

    attribute :last_used_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :expires_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :revoked_at, :utc_datetime_usec do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_key_hash, [:key_hash])
  end

  relationships do
    belongs_to :organisation, FounderPad.Accounts.Organisation do
      allow_nil?(false)
      attribute_type(:uuid)
    end

    belongs_to :created_by, FounderPad.Accounts.User do
      allow_nil?(false)
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :scopes, :expires_at, :organisation_id, :created_by_id])

      change(fn changeset, _context ->
        raw_key = generate_raw_key()
        prefix = "fp_" <> String.slice(raw_key, 0, 8)
        hash = :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)

        changeset
        |> Ash.Changeset.force_change_attribute(:key_prefix, prefix)
        |> Ash.Changeset.force_change_attribute(:key_hash, hash)
        |> Ash.Changeset.after_action(fn _changeset, key ->
          {:ok, Map.put(key, :__raw_key__, raw_key)}
        end)
      end)
    end

    update :revoke do
      accept([])
      change(set_attribute(:revoked_at, &DateTime.utc_now/0))
    end

    update :touch_last_used do
      accept([])
      change(set_attribute(:last_used_at, &DateTime.utc_now/0))
    end

    read :active do
      filter(expr(is_nil(revoked_at) and (is_nil(expires_at) or expires_at > now())))
    end

    read :by_organisation do
      argument(:organisation_id, :uuid, allow_nil?: false)
      filter(expr(organisation_id == ^arg(:organisation_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :by_key_hash do
      argument(:hash, :string, allow_nil?: false)
      filter(expr(key_hash == ^arg(:hash) and is_nil(revoked_at)))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if(always())
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if(always())
    end
  end

  defp generate_raw_key do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
