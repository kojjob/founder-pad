defmodule FounderPad.Compliance.BusinessVerification do
  @moduledoc """
  A business (KYB) identity check.

  Like individual verification: the raw registration number and TIN are accepted as
  transient arguments and hashed (SHA-256); only the hashes are persisted. The
  provider call, risk and status transition run via
  `FounderPad.Compliance.KybVerifications`.
  """
  use Ash.Resource,
    domain: FounderPad.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @modes [:test, :live]
  @statuses [:pending, :processing, :verified, :failed, :requires_review, :cancelled, :expired]
  @risk_levels [:low, :medium, :high]

  postgres do
    table("business_verifications")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :external_id, :string do
      public?(true)
    end

    attribute :mode, :atom do
      constraints(one_of: @modes)
      default(:test)
      allow_nil?(false)
      public?(true)
    end

    attribute :registered_name, :string do
      public?(true)
    end

    attribute :registration_number_hash, :string do
      allow_nil?(false)
    end

    attribute :tin_hash, :string do
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: @statuses)
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :provider_name, :string do
      public?(true)
    end

    attribute :provider_reference, :string do
      public?(true)
    end

    attribute :risk_level, :atom do
      constraints(one_of: @risk_levels)
      public?(true)
    end

    attribute :reason_codes, {:array, :string} do
      default([])
      public?(true)
    end

    attribute :completed_at, :utc_datetime_usec do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_external_id_per_org, [:organisation_id, :external_id])
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

      argument(:registration_number, :string, allow_nil?: false)
      argument(:tin, :string)

      accept([:external_id, :mode, :registered_name, :organisation_id])

      change(&hash_identifiers/2)
    end

    update :apply_provider_result do
      accept([:status, :risk_level, :reason_codes, :provider_name, :provider_reference])
      require_atomic?(false)
      change(set_attribute(:completed_at, &DateTime.utc_now/0))
    end

    read :by_organisation do
      argument(:organisation_id, :uuid, allow_nil?: false)
      filter(expr(organisation_id == ^arg(:organisation_id)))
      prepare(build(sort: [inserted_at: :desc]))
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

  defp hash_identifiers(changeset, _context) do
    reg = Ash.Changeset.get_argument(changeset, :registration_number)
    tin = Ash.Changeset.get_argument(changeset, :tin)

    changeset
    |> Ash.Changeset.force_change_attribute(:registration_number_hash, hash(reg))
    |> maybe_hash_tin(tin)
  end

  defp maybe_hash_tin(changeset, nil), do: changeset
  defp maybe_hash_tin(changeset, ""), do: changeset

  defp maybe_hash_tin(changeset, tin) do
    Ash.Changeset.force_change_attribute(changeset, :tin_hash, hash(tin))
  end

  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
