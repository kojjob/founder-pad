defmodule FounderPad.Compliance.IndividualVerification do
  @moduledoc """
  A person identity check against a Ghana Card.

  Security invariants enforced here:

    * The raw Ghana Card number and phone number are accepted only as transient
      action arguments and are immediately hashed (SHA-256). Only the hashes are
      persisted — never the raw identifiers.
    * In `:live` mode the check cannot be created without an `:active`
      `ConsentReceipt` (consent before processing).

  The actual provider call, risk scoring and status transition run asynchronously
  in `FounderPad.Compliance.Workers.IndividualVerificationWorker`, which uses
  `:apply_provider_result` to record the normalized outcome.
  """
  use Ash.Resource,
    domain: FounderPad.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias FounderPad.Compliance.ConsentReceipt

  @modes [:test, :live]
  @statuses [:pending, :processing, :verified, :failed, :requires_review, :cancelled, :expired]
  @match_levels [:none, :weak, :medium, :strong]
  @risk_levels [:low, :medium, :high]

  postgres do
    table("individual_verifications")
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

    attribute :ghana_card_number_hash, :string do
      allow_nil?(false)
    end

    attribute :first_name, :string do
      public?(true)
    end

    attribute :last_name, :string do
      public?(true)
    end

    attribute :date_of_birth, :date do
      public?(true)
    end

    attribute :phone_number_hash, :string do
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

    attribute :identity_verified, :boolean do
      default(false)
      public?(true)
    end

    attribute :match_level, :atom do
      constraints(one_of: @match_levels)
      default(:none)
      public?(true)
    end

    attribute :risk_level, :atom do
      constraints(one_of: @risk_levels)
      public?(true)
    end

    attribute :risk_score, :integer do
      constraints(min: 0, max: 100)
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

    belongs_to :consent_receipt, FounderPad.Compliance.ConsentReceipt do
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      argument(:ghana_card_number, :string, allow_nil?: false)
      argument(:phone_number, :string)

      accept([
        :external_id,
        :mode,
        :consent_receipt_id,
        :first_name,
        :last_name,
        :date_of_birth,
        :organisation_id
      ])

      change(&hash_identifiers/2)
      change(&enforce_consent_for_live/2)
    end

    update :apply_provider_result do
      accept([
        :status,
        :identity_verified,
        :match_level,
        :reason_codes,
        :provider_name,
        :provider_reference,
        :risk_level,
        :risk_score
      ])

      require_atomic?(false)
      change(set_attribute(:completed_at, &DateTime.utc_now/0))
    end

    update :mark_processing do
      accept([])
      change(set_attribute(:status, :processing))
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
    card = Ash.Changeset.get_argument(changeset, :ghana_card_number)
    phone = Ash.Changeset.get_argument(changeset, :phone_number)

    changeset
    |> Ash.Changeset.force_change_attribute(:ghana_card_number_hash, hash(card))
    |> maybe_hash_phone(phone)
  end

  defp maybe_hash_phone(changeset, nil), do: changeset
  defp maybe_hash_phone(changeset, ""), do: changeset

  defp maybe_hash_phone(changeset, phone) do
    Ash.Changeset.force_change_attribute(changeset, :phone_number_hash, hash(phone))
  end

  defp enforce_consent_for_live(changeset, _context) do
    case Ash.Changeset.get_attribute(changeset, :mode) do
      :live -> validate_active_consent(changeset)
      _ -> changeset
    end
  end

  defp validate_active_consent(changeset) do
    consent_id = Ash.Changeset.get_attribute(changeset, :consent_receipt_id)

    with id when not is_nil(id) <- consent_id,
         {:ok, receipt} <- Ash.get(ConsentReceipt, id, authorize?: false),
         true <- ConsentReceipt.active?(receipt) do
      changeset
    else
      _ ->
        Ash.Changeset.add_error(changeset,
          field: :consent_receipt_id,
          message: "consent_required: an active consent receipt is required for live verification"
        )
    end
  end

  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
