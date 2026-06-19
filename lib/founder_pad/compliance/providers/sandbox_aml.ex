defmodule FounderPad.Compliance.Providers.SandboxAml do
  @moduledoc """
  Deterministic sandbox AML provider keyed on the subject name. A name containing
  `AML-PEP`, `AML-SANCTION` or `AML-ADVERSE` returns a `:possible_match` (never an
  auto-`:confirmed_match` — a human must confirm). `AML-DOWN` simulates an outage;
  anything else is `:clear`. Contacts no external service.
  """
  @behaviour FounderPad.Compliance.Providers.AmlProvider

  @lists ["sanctions", "pep", "adverse_media"]
  @name "sandbox"

  @impl true
  def name, do: @name

  @impl true
  def screen(%{name: name}) when is_binary(name) do
    cond do
      String.contains?(name, "AML-DOWN") ->
        {:error, :provider_unavailable}

      String.contains?(name, "AML-SANCTION") ->
        {:ok, hit(["sanctions"], 0.92, ["sanctions_possible_match"], name)}

      String.contains?(name, "AML-PEP") ->
        {:ok, hit(["pep"], 0.71, ["pep_possible_match"], name)}

      String.contains?(name, "AML-ADVERSE") ->
        {:ok, hit(["adverse_media"], 0.6, ["adverse_media_possible_match"], name)}

      true ->
        {:ok, clear(name)}
    end
  end

  def screen(_input), do: {:error, :invalid_input}

  defp hit(lists, confidence, reason_codes, name) do
    %{
      status: :possible_match,
      lists_checked: lists,
      match_count: 1,
      highest_confidence: confidence,
      reason_codes: reason_codes,
      provider_name: @name,
      provider_reference: reference(name)
    }
  end

  defp clear(name) do
    %{
      status: :clear,
      lists_checked: @lists,
      match_count: 0,
      highest_confidence: 0.0,
      reason_codes: ["no_match"],
      provider_name: @name,
      provider_reference: reference(name)
    }
  end

  defp reference(name) do
    digest = :crypto.hash(:sha256, name) |> Base.encode16(case: :lower)
    "aml_" <> String.slice(digest, 0, 16)
  end
end
