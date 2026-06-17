defmodule FounderPad.Compliance.Verifications do
  @moduledoc """
  Orchestrates the individual verification lifecycle: call the configured identity
  provider, score risk (`rules_v1`), derive the final status and record the
  normalized outcome on the verification.

  The raw Ghana Card number is passed in transiently (it is never persisted on the
  record) so the provider can be called; only the result is stored.
  """

  alias FounderPad.Compliance
  alias FounderPad.Compliance.{IndividualVerification, Risk}

  @doc """
  Run an individual verification through the provider and apply the outcome.

  Returns `{:ok, verification}` on a completed decision, or `{:error, reason}` if
  the provider is unavailable (the check is left unfinished for retry).
  """
  @spec process(IndividualVerification.t(), String.t()) ::
          {:ok, IndividualVerification.t()} | {:error, atom()}
  def process(%IndividualVerification{} = verification, ghana_card_number) do
    input = %{
      ghana_card_number: ghana_card_number,
      first_name: verification.first_name,
      last_name: verification.last_name,
      date_of_birth: verification.date_of_birth
    }

    case provider().verify(input) do
      {:ok, result} -> apply_result(verification, result)
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_result(verification, result) do
    risk = Risk.assess(result)
    status = Risk.final_status(result.status, risk.level)
    reason_codes = Enum.uniq(result.reason_codes ++ risk.reason_codes)

    result_attrs = %{
      status: status,
      identity_verified: result.identity_verified,
      match_level: result.match_level,
      reason_codes: reason_codes,
      provider_name: result.provider_name,
      provider_reference: result.provider_reference,
      risk_level: risk.level,
      risk_score: risk.score
    }

    with {:ok, updated} <-
           verification
           |> Ash.Changeset.for_update(:apply_provider_result, result_attrs)
           |> Ash.update() do
      maybe_open_review_case(updated)
      {:ok, updated}
    end
  end

  # A check that needs human review gets a review case opened automatically, so it
  # lands in the compliance queue regardless of how it was submitted.
  defp maybe_open_review_case(%{status: :requires_review} = ivf) do
    Compliance.open_review_case(%{
      organisation_id: ivf.organisation_id,
      subject_type: :individual_verification,
      subject_id: ivf.id,
      priority: review_priority(ivf.risk_level)
    })
  end

  defp maybe_open_review_case(_ivf), do: :ok

  defp review_priority(:high), do: :high
  defp review_priority(_), do: :normal

  @doc "The configured identity provider module (sandbox by default)."
  def provider do
    Application.get_env(:founder_pad, :identity_provider, FounderPad.Compliance.Providers.Sandbox)
  end
end
