defmodule FounderPad.Compliance.KybVerifications do
  @moduledoc """
  Orchestrates the business (KYB) verification lifecycle: call the configured KYB
  provider, derive the final status (escalating to review on medium/high risk) and
  record the outcome. Opens a review case when the check needs human review.

  The raw registration number is passed transiently (it is never persisted on the
  record) so the provider can be called.
  """

  alias FounderPad.Compliance
  alias FounderPad.Compliance.{BusinessVerification, Risk}

  @spec process(BusinessVerification.t(), String.t()) ::
          {:ok, BusinessVerification.t()} | {:error, atom()}
  def process(%BusinessVerification{} = bv, registration_number) do
    input = %{registration_number: registration_number, registered_name: bv.registered_name}

    case provider().verify(input) do
      {:ok, result} -> apply_result(bv, result)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "The configured KYB provider module (sandbox by default)."
  def provider do
    Application.get_env(:founder_pad, :kyb_provider, FounderPad.Compliance.Providers.SandboxKyb)
  end

  defp apply_result(bv, result) do
    status = Risk.final_status(result.status, result.risk_level)

    attrs = %{
      status: status,
      risk_level: result.risk_level,
      reason_codes: result.reason_codes,
      provider_name: result.provider_name,
      provider_reference: result.provider_reference
    }

    with {:ok, updated} <-
           bv |> Ash.Changeset.for_update(:apply_provider_result, attrs) |> Ash.update() do
      maybe_open_review_case(updated)
      {:ok, updated}
    end
  end

  defp maybe_open_review_case(%{status: :requires_review} = bv) do
    Compliance.open_review_case(%{
      organisation_id: bv.organisation_id,
      subject_type: :business_verification,
      subject_id: bv.id,
      priority: review_priority(bv.risk_level)
    })
  end

  defp maybe_open_review_case(_bv), do: :ok

  defp review_priority(:high), do: :high
  defp review_priority(_), do: :normal
end
