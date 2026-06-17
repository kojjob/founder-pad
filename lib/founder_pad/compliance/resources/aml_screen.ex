defmodule FounderPad.Compliance.AmlScreen do
  @moduledoc """
  Result of an AML screen (sanctions/PEP/adverse-media) for a person or business.

  A non-clear result is `:possible_match` until a human confirms it — there is no
  automated final AML decision.
  """
  use Ash.Resource,
    domain: FounderPad.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @subject_types [:person, :business]
  @statuses [:pending, :clear, :possible_match, :confirmed_match, :failed]

  postgres do
    table("aml_screens")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :subject_type, :atom do
      constraints(one_of: @subject_types)
      allow_nil?(false)
      public?(true)
    end

    attribute :subject_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

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

    attribute :lists_checked, {:array, :string} do
      default([])
      public?(true)
    end

    attribute :match_count, :integer do
      default(0)
      public?(true)
    end

    attribute :highest_confidence, :decimal do
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
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :subject_type,
        :subject_id,
        :provider_name,
        :provider_reference,
        :status,
        :lists_checked,
        :match_count,
        :highest_confidence,
        :reason_codes,
        :organisation_id
      ])
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
end
