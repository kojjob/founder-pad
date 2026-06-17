defmodule FounderPad.Compliance.Risk do
  @moduledoc """
  Deterministic, explainable risk scoring (`rules_v1`).

  Combines the normalized identity provider result into a 0–100 score and a
  low/medium/high level. Every output carries the reason codes and model version
  so a compliance officer can always explain *why* a check landed where it did
  (a hard requirement for regulated clients). No ML — rules only — for MVP.
  """

  @model_version "rules_v1"

  @type assessment :: %{
          score: 0..100,
          level: :low | :medium | :high,
          reason_codes: [String.t()],
          model_version: String.t()
        }

  @doc "Score a normalized provider result into a risk assessment."
  @spec assess(map()) :: assessment()
  def assess(%{status: status, match_level: match_level} = result) do
    score = base_score(status, match_level)

    %{
      score: score,
      level: level_for(score),
      reason_codes: Map.get(result, :reason_codes, []),
      model_version: @model_version
    }
  end

  @doc """
  The final verification status given the provider status and computed risk level.

  A provider may report `:verified`, but a medium/high risk level escalates the
  check to manual review rather than auto-approving it (manual review before
  risky automation).
  """
  @spec final_status(atom(), :low | :medium | :high) :: atom()
  def final_status(:verified, :low), do: :verified
  def final_status(:verified, _risk), do: :requires_review
  def final_status(provider_status, _risk), do: provider_status

  # Strong, confirmed identity → low. Weak/partial → medium. No match/failure → high.
  defp base_score(:verified, :strong), do: 15
  defp base_score(:verified, :medium), do: 45
  defp base_score(:verified, :weak), do: 55
  defp base_score(:requires_review, _), do: 55
  defp base_score(:failed, _), do: 85
  defp base_score(_status, :none), do: 80
  defp base_score(_status, _match), do: 50

  defp level_for(score) when score <= 30, do: :low
  defp level_for(score) when score <= 65, do: :medium
  defp level_for(_score), do: :high
end
