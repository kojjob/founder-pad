defmodule FounderPad.Compliance.Providers.SandboxKyb do
  @moduledoc """
  Deterministic sandbox KYB provider keyed on the registration number
  (`CS-TEST-*` fixtures). Contacts no external registry.
  """
  @behaviour FounderPad.Compliance.Providers.KybProvider

  @name "sandbox"

  @impl true
  def name, do: @name

  @impl true
  def verify(%{registration_number: "CS-TEST-VERIFIED-1"}) do
    {:ok, result(:verified, :low, ["registry_match", "active_status"], "CS-TEST-VERIFIED-1")}
  end

  def verify(%{registration_number: "CS-TEST-REVIEW-1"}) do
    {:ok,
     result(
       :requires_review,
       :medium,
       ["partial_match", "directors_unverified"],
       "CS-TEST-REVIEW-1"
     )}
  end

  def verify(%{registration_number: "CS-TEST-FAILED-1"}) do
    {:ok, result(:failed, :high, ["no_registry_match"], "CS-TEST-FAILED-1")}
  end

  def verify(%{registration_number: "CS-TEST-PROVIDER-DOWN"}) do
    {:error, :provider_unavailable}
  end

  def verify(%{registration_number: reg}) when is_binary(reg) and reg != "" do
    {:ok, result(:verified, :low, ["registry_match"], reg)}
  end

  def verify(_input), do: {:error, :invalid_input}

  defp result(status, risk_level, reason_codes, reg) do
    digest = :crypto.hash(:sha256, reg) |> Base.encode16(case: :lower)

    %{
      status: status,
      risk_level: risk_level,
      reason_codes: reason_codes,
      provider_name: @name,
      provider_reference: "kyb_" <> String.slice(digest, 0, 16)
    }
  end
end
