defmodule FounderPad.Compliance.AmlScreening do
  @moduledoc """
  Runs an AML screen for a subject, records it, and routes any match to the manual
  review queue (no automated final AML decision). Swappable provider via `:aml_provider`.
  """

  alias FounderPad.Compliance
  alias FounderPad.Compliance.AmlScreen

  @spec screen(Ecto.UUID.t(), :person | :business, Ecto.UUID.t(), String.t()) ::
          {:ok, AmlScreen.t()} | {:error, atom()}
  def screen(org_id, subject_type, subject_id, name) do
    case provider().screen(%{name: name, subject_type: subject_type}) do
      {:ok, result} -> record(org_id, subject_type, subject_id, result)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "The configured AML provider module (sandbox by default)."
  def provider do
    Application.get_env(:founder_pad, :aml_provider, FounderPad.Compliance.Providers.SandboxAml)
  end

  defp record(org_id, subject_type, subject_id, result) do
    confidence = result.highest_confidence && Decimal.from_float(result.highest_confidence)

    with {:ok, screen} <-
           AmlScreen
           |> Ash.Changeset.for_create(:create, %{
             organisation_id: org_id,
             subject_type: subject_type,
             subject_id: subject_id,
             provider_name: result.provider_name,
             provider_reference: result.provider_reference,
             status: result.status,
             lists_checked: result.lists_checked,
             match_count: result.match_count,
             highest_confidence: confidence,
             reason_codes: result.reason_codes
           })
           |> Ash.create() do
      maybe_open_review(org_id, screen)
      {:ok, screen}
    end
  end

  # Any non-clear AML result needs a human decision.
  defp maybe_open_review(org_id, %{status: status} = screen)
       when status in [:possible_match, :confirmed_match] do
    Compliance.open_review_case(%{
      organisation_id: org_id,
      subject_type: :aml_screen,
      subject_id: screen.id,
      priority: :high
    })
  end

  defp maybe_open_review(_org_id, _screen), do: :ok
end
