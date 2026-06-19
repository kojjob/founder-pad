defmodule FounderPad.Compliance.Providers.Sandbox do
  @moduledoc """
  Deterministic sandbox identity provider.

  Returns fixed outcomes for the documented `GHA-TEST-*` fixtures so developers
  can integrate against predictable responses, and a stable default for any other
  well-formed card number. Never contacts an external service — this is the only
  provider enabled until an approved live route exists (ADR-003).
  """
  @behaviour FounderPad.Compliance.Providers.IdentityProvider

  @name "sandbox"

  @impl true
  def name, do: @name

  @impl true
  def verify(%{ghana_card_number: "GHA-TEST-VERIFIED-1"} = _input) do
    {:ok,
     result(:verified, true, :strong, ["identity_match", "name_match"], "GHA-TEST-VERIFIED-1")}
  end

  def verify(%{ghana_card_number: "GHA-TEST-FAILED-1"}) do
    {:ok, result(:failed, false, :none, ["no_match"], "GHA-TEST-FAILED-1")}
  end

  def verify(%{ghana_card_number: "GHA-TEST-REVIEW-1"}) do
    {:ok,
     result(
       :requires_review,
       false,
       :medium,
       ["partial_match", "manual_review"],
       "GHA-TEST-REVIEW-1"
     )}
  end

  def verify(%{ghana_card_number: "GHA-TEST-PROVIDER-DOWN"}) do
    {:error, :provider_unavailable}
  end

  def verify(%{ghana_card_number: card}) when is_binary(card) and card != "" do
    {:ok, result(:verified, true, :strong, ["identity_match"], card)}
  end

  def verify(_input), do: {:error, :invalid_input}

  defp result(status, verified?, match_level, reason_codes, card) do
    %{
      status: status,
      identity_verified: verified?,
      match_level: match_level,
      reason_codes: reason_codes,
      provider_name: @name,
      provider_reference: provider_reference(card)
    }
  end

  defp provider_reference(card) do
    digest = :crypto.hash(:sha256, card) |> Base.encode16(case: :lower)
    "sbx_" <> String.slice(digest, 0, 16)
  end
end
