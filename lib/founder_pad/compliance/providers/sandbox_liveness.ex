defmodule FounderPad.Compliance.Providers.SandboxLiveness do
  @moduledoc """
  Deterministic sandbox liveness provider. A reference containing `FAIL` fails,
  one containing `REVIEW` needs manual review, anything else passes with high
  confidence. Contacts no external service.
  """
  @behaviour FounderPad.Compliance.Providers.LivenessProvider

  @name "sandbox"

  @impl true
  def name, do: @name

  @impl true
  def check(%{reference: reference}) when is_binary(reference) do
    cond do
      String.contains?(reference, "FAIL") ->
        {:ok, result(:failed, 0.2, ["liveness_failed"], reference)}

      String.contains?(reference, "REVIEW") ->
        {:ok, result(:requires_review, 0.5, ["liveness_uncertain"], reference)}

      true ->
        {:ok, result(:passed, 0.95, ["liveness_passed"], reference)}
    end
  end

  def check(_input), do: {:error, :invalid_input}

  defp result(status, confidence, reason_codes, reference) do
    digest = :crypto.hash(:sha256, reference) |> Base.encode16(case: :lower)

    %{
      status: status,
      confidence_score: confidence,
      reason_codes: reason_codes,
      provider_name: @name,
      provider_reference: "live_" <> String.slice(digest, 0, 16)
    }
  end
end
