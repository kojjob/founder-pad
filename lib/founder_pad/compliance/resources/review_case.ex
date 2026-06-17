defmodule FounderPad.Compliance.ReviewCase do
  @moduledoc """
  A manual review workflow for a compliance subject (an individual verification,
  business verification or AML screen) that could not be auto-decided.

  Every terminal decision (`approve`/`reject`/`request_more_info`) requires a
  reason — the decision audit trail a regulated client must produce.
  """
  use Ash.Resource,
    domain: FounderPad.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @subject_types [:individual_verification, :business_verification, :aml_screen]
  @statuses [:open, :assigned, :approved, :rejected, :more_info_requested, :closed]
  @priorities [:low, :normal, :high, :urgent]

  postgres do
    table("review_cases")
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

    attribute :status, :atom do
      constraints(one_of: @statuses)
      default(:open)
      allow_nil?(false)
      public?(true)
    end

    attribute :priority, :atom do
      constraints(one_of: @priorities)
      default(:normal)
      allow_nil?(false)
      public?(true)
    end

    attribute :assigned_to_user_id, :uuid do
      public?(true)
    end

    attribute :decision_reason, :string do
      public?(true)
    end

    attribute :closed_at, :utc_datetime_usec do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :organisation, FounderPad.Accounts.Organisation do
      allow_nil?(false)
      attribute_type(:uuid)
    end

    has_many :notes, FounderPad.Compliance.ReviewNote do
      destination_attribute(:review_case_id)
    end
  end

  actions do
    defaults([:read])

    create :open do
      primary?(true)
      accept([:subject_type, :subject_id, :priority, :assigned_to_user_id, :organisation_id])
    end

    update :assign do
      accept([:assigned_to_user_id])
      change(set_attribute(:status, :assigned))
    end

    update :approve do
      accept([:decision_reason])
      validate(present(:decision_reason))
      require_atomic?(false)
      change(set_attribute(:status, :approved))
      change(set_attribute(:closed_at, &DateTime.utc_now/0))
    end

    update :reject do
      accept([:decision_reason])
      validate(present(:decision_reason))
      require_atomic?(false)
      change(set_attribute(:status, :rejected))
      change(set_attribute(:closed_at, &DateTime.utc_now/0))
    end

    update :request_more_info do
      accept([:decision_reason])
      validate(present(:decision_reason))
      require_atomic?(false)
      change(set_attribute(:status, :more_info_requested))
    end

    read :by_organisation do
      argument(:organisation_id, :uuid, allow_nil?: false)
      filter(expr(organisation_id == ^arg(:organisation_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :open_cases do
      argument(:organisation_id, :uuid, allow_nil?: false)

      filter(
        expr(
          organisation_id == ^arg(:organisation_id) and
            status in [:open, :assigned, :more_info_requested]
        )
      )

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
