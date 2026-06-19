defmodule FounderPad.Compliance.Retention do
  @moduledoc """
  Data-minimisation retention sweep. Redacts webhook delivery payloads past their
  retention window and marks expired evidence items deleted. Windows are configurable
  per `:retention` config; defaults follow the compliance policy (short for payloads
  and raw evidence).

  `run/1` takes the current time so it is deterministically testable.
  """
  import Ecto.Query
  require Ash.Query

  alias FounderPad.Compliance.EvidenceItem
  alias FounderPad.Repo
  alias FounderPad.Webhooks.WebhookDelivery

  @default_webhook_days 30

  @doc "Run the retention sweep as of `now`. Returns counts of redacted/expired records."
  def run(now \\ DateTime.utc_now()) do
    %{
      webhooks_redacted: redact_webhook_payloads(now),
      evidence_expired: expire_evidence(now)
    }
  end

  defp redact_webhook_payloads(now) do
    cutoff = DateTime.add(now, -webhook_days() * 86_400, :second)

    {count, _} =
      from(d in WebhookDelivery,
        where: d.inserted_at < ^cutoff and d.payload != ^%{},
        update: [set: [payload: ^%{}]]
      )
      |> Repo.update_all([])

    count
  end

  defp expire_evidence(now) do
    EvidenceItem
    |> Ash.Query.filter(not is_nil(expires_at) and expires_at < ^now and status != :deleted)
    |> Ash.read!(authorize?: false)
    |> Enum.map(fn item ->
      item |> Ash.Changeset.for_update(:mark_deleted, %{}) |> Ash.update!()
    end)
    |> length()
  end

  defp webhook_days do
    Application.get_env(:founder_pad, :retention, [])
    |> Keyword.get(:webhook_payload_days, @default_webhook_days)
  end
end
