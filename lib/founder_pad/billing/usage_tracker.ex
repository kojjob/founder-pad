defmodule FounderPad.Billing.UsageTracker do
  @moduledoc "Tracks API usage against plan limits and records metered usage."

  require Ash.Query

  def track_api_call(org_id) do
    FounderPad.Billing.UsageRecord
    |> Ash.Changeset.for_create(:create, %{
      event_type: "api_call",
      quantity: 1,
      organisation_id: org_id
    })
    |> Ash.create()
  end

  def get_usage_count(org_id, period_start) do
    FounderPad.Billing.UsageRecord
    |> Ash.Query.filter(
      organisation_id == ^org_id and event_type == "api_call" and inserted_at >= ^period_start
    )
    |> Ash.read!()
    |> length()
  end

  def within_limits?(org_id) do
    case get_org_plan(org_id) do
      nil ->
        true

      plan ->
        period_start = beginning_of_month()
        current = get_usage_count(org_id, period_start)
        current < (plan.max_api_calls_per_month || 999_999)
    end
  end

  defp get_org_plan(org_id) do
    case FounderPad.Billing.Subscription
         |> Ash.Query.filter(organisation_id == ^org_id and status == :active)
         |> Ash.Query.load([:plan])
         |> Ash.read!() do
      [sub | _] -> sub.plan
      [] -> nil
    end
  end

  defp beginning_of_month do
    today = Date.utc_today()
    {:ok, dt} = NaiveDateTime.new(today.year, today.month, 1, 0, 0, 0)
    DateTime.from_naive!(dt, "Etc/UTC")
  end
end
