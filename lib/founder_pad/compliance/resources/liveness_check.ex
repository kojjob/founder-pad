defmodule FounderPad.Compliance.LivenessCheck do
  @moduledoc "Result of a selfie/liveness check against an individual verification."
  use Ash.Resource,
    domain: FounderPad.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @statuses [:pending, :passed, :failed, :requires_review]

  postgres do
    table("liveness_checks")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :provider_name, :string do
      public?(true)
    end

    attribute :provider_reference, :string do
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: @statuses)
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :confidence_score, :decimal do
      public?(true)
    end

    attribute :reason_codes, {:array, :string} do
      default([])
      public?(true)
    end

    create_timestamp(:inserted_at)
  end

  relationships do
    belongs_to :organisation, FounderPad.Accounts.Organisation do
      allow_nil?(false)
      attribute_type(:uuid)
    end

    belongs_to :individual_verification, FounderPad.Compliance.IndividualVerification do
      allow_nil?(false)
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :provider_name,
        :provider_reference,
        :status,
        :confidence_score,
        :reason_codes,
        :organisation_id,
        :individual_verification_id
      ])
    end

    read :by_verification do
      argument(:individual_verification_id, :uuid, allow_nil?: false)
      filter(expr(individual_verification_id == ^arg(:individual_verification_id)))
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
end
