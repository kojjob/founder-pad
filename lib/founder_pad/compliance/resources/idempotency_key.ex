defmodule FounderPad.Compliance.IdempotencyKey do
  @moduledoc """
  Records the first response produced for a client-supplied `Idempotency-Key` on a
  write endpoint, scoped per tenant.

  A retry carrying the same key replays the stored response (no duplicate work, no
  re-fired side effects). The same key with a different request body is a conflict
  (`duplicate_idempotency_key`) — the `request_fingerprint` detects that.
  """
  use Ash.Resource,
    domain: FounderPad.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("idempotency_keys")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :key, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :request_fingerprint, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :response_status, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :response_body, :map do
      default(%{})
      public?(true)
    end

    create_timestamp(:inserted_at)
  end

  identities do
    identity(:unique_key_per_org, [:organisation_id, :key])
  end

  relationships do
    belongs_to :organisation, FounderPad.Accounts.Organisation do
      allow_nil?(false)
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:key, :request_fingerprint, :response_status, :response_body, :organisation_id])
    end

    read :by_org_key do
      argument(:organisation_id, :uuid, allow_nil?: false)
      argument(:key, :string, allow_nil?: false)
      get?(true)
      filter(expr(organisation_id == ^arg(:organisation_id) and key == ^arg(:key)))
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
end
