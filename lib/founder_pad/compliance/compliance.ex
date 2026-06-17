defmodule FounderPad.Compliance do
  @moduledoc """
  GhanaTrust compliance domain.

  Owns the regulated KYC/KYB/AML surface that is specific to GhanaTrust:
  consent receipts, individual identity verifications, business verifications,
  evidence, AML screening, risk assessment and manual review.

  Horizontal concerns (auth, tenancy, API keys, webhooks, audit, billing) are
  inherited from the surrounding platform domains.
  """
  use Ash.Domain

  resources do
    resource FounderPad.Compliance.ConsentReceipt do
      define(:create_consent_receipt, action: :create)
      define(:withdraw_consent_receipt, action: :withdraw)

      define(:list_consent_receipts_by_organisation,
        action: :by_organisation,
        args: [:organisation_id]
      )
    end

    resource FounderPad.Compliance.IndividualVerification do
      define(:create_individual_verification, action: :create)
      define(:apply_individual_verification_result, action: :apply_provider_result)

      define(:list_individual_verifications_by_organisation,
        action: :by_organisation,
        args: [:organisation_id]
      )
    end

    resource FounderPad.Compliance.ReviewCase do
      define(:open_review_case, action: :open)
      define(:assign_review_case, action: :assign)

      define(:list_review_cases_by_organisation,
        action: :by_organisation,
        args: [:organisation_id]
      )

      define(:list_open_review_cases, action: :open_cases, args: [:organisation_id])
    end

    resource FounderPad.Compliance.ReviewNote do
      define(:create_review_note, action: :create)
      define(:list_review_notes, action: :by_case, args: [:review_case_id])
    end

    resource FounderPad.Compliance.IdempotencyKey do
      define(:create_idempotency_key, action: :create)
      define(:find_idempotency_key, action: :by_org_key, args: [:organisation_id, :key])
    end

    resource FounderPad.Compliance.EvidenceItem do
      define(:request_evidence_upload, action: :request_upload)
      define(:mark_evidence_uploaded, action: :mark_uploaded)

      define(:list_evidence_by_verification,
        action: :by_verification,
        args: [:individual_verification_id]
      )
    end

    resource FounderPad.Compliance.LivenessCheck do
      define(:create_liveness_check, action: :create)

      define(:list_liveness_by_verification,
        action: :by_verification,
        args: [:individual_verification_id]
      )
    end
  end
end
