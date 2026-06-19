defmodule FounderPad.Compliance.Metering do
  @moduledoc """
  Records a billing usage event per compliance check, against the existing Billing
  domain. Only live-mode usage is `billable` — sandbox/test usage is recorded for
  visibility but not charged.
  """

  @doc "Record one metered usage event of `usage_type` for an org in the given mode."
  @spec meter(Ecto.UUID.t(), String.t(), :test | :live) :: {:ok, struct()} | {:error, term()}
  def meter(org_id, usage_type, mode) do
    FounderPad.Billing.UsageRecord
    |> Ash.Changeset.for_create(:create, %{
      event_type: usage_type,
      quantity: 1,
      metadata: %{"mode" => to_string(mode), "billable" => mode == :live},
      organisation_id: org_id
    })
    |> Ash.create()
  end
end
