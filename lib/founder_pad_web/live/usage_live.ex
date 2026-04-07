defmodule FounderPadWeb.UsageLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  alias FounderPad.Billing.UsageTracker

  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]
    org_id = get_user_org_id(user)
    period_start = beginning_of_month()
    plan = get_org_plan(org_id)
    usage_count = UsageTracker.get_usage_count(org_id, period_start)
    limit = if plan, do: plan.max_api_calls_per_month || 999_999, else: 999_999
    plan_name = if plan, do: plan.name, else: "Free"
    history = load_usage_history(org_id)

    {:ok,
     assign(socket,
       active_nav: :billing,
       page_title: "API Usage",
       org_id: org_id,
       usage_count: usage_count,
       limit: limit,
       plan_name: plan_name,
       period_start: period_start,
       history: history,
       plan: plan
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-5xl mx-auto">
      <div>
        <h1 class="text-3xl font-extrabold font-headline tracking-tight text-on-surface">
          API Usage
        </h1>
        <p class="text-on-surface-variant mt-1">
          Current billing period usage for your <span class="font-semibold">{@plan_name}</span> plan
        </p>
      </div>

      <%!-- Usage Bar Chart --%>
      <div class="bg-surface-container rounded-2xl p-6 space-y-4">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-bold text-on-surface">API Calls This Period</h2>
          <span class="text-sm text-on-surface-variant font-mono">
            {@usage_count} / {format_limit(@limit)}
          </span>
        </div>

        <div class="w-full bg-surface-container-high rounded-full h-6 overflow-hidden">
          <div
            class={[
              "h-full rounded-full transition-all duration-500",
              usage_bar_color(usage_percentage(@usage_count, @limit))
            ]}
            style={"width: #{min(usage_percentage(@usage_count, @limit), 100)}%"}
          >
          </div>
        </div>

        <div class="flex justify-between text-xs text-on-surface-variant">
          <span>{usage_percentage(@usage_count, @limit)}% used</span>
          <span>{@limit - @usage_count} remaining</span>
        </div>
      </div>

      <%!-- Plan Limits Summary --%>
      <div class="bg-surface-container rounded-2xl p-6">
        <h2 class="text-lg font-bold text-on-surface mb-4">Plan Limits</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="bg-surface-container-high rounded-xl p-4">
            <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-1">
              API Calls / Month
            </p>
            <p class="text-2xl font-mono font-medium text-on-surface">{format_limit(@limit)}</p>
          </div>
          <div class="bg-surface-container-high rounded-xl p-4">
            <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-1">
              Max Agents
            </p>
            <p class="text-2xl font-mono font-medium text-on-surface">
              {if @plan, do: @plan.max_agents, else: "Unlimited"}
            </p>
          </div>
          <div class="bg-surface-container-high rounded-xl p-4">
            <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-1">
              Max Seats
            </p>
            <p class="text-2xl font-mono font-medium text-on-surface">
              {if @plan, do: @plan.max_seats, else: "Unlimited"}
            </p>
          </div>
        </div>
      </div>

      <%!-- Usage History Table --%>
      <div class="bg-surface-container rounded-2xl p-6">
        <h2 class="text-lg font-bold text-on-surface mb-4">Usage History</h2>
        <%= if @history == [] do %>
          <p class="text-on-surface-variant text-sm">No usage records yet</p>
        <% else %>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-outline-variant text-left">
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">
                    Event Type
                  </th>
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">
                    Quantity
                  </th>
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">
                    Date
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={record <- @history}
                  class="border-b border-outline-variant/50 hover:bg-surface-container-high transition-colors"
                >
                  <td class="py-3 px-4 font-mono text-on-surface">{record.event_type}</td>
                  <td class="py-3 px-4 font-mono text-on-surface">{record.quantity}</td>
                  <td class="py-3 px-4 text-on-surface-variant">
                    {Calendar.strftime(record.inserted_at, "%b %d, %Y %H:%M")}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp usage_percentage(_used, 0), do: 0
  defp usage_percentage(used, limit), do: round(used / limit * 100)

  defp usage_bar_color(pct) when pct >= 90, do: "bg-error"
  defp usage_bar_color(pct) when pct >= 70, do: "bg-warning"
  defp usage_bar_color(_pct), do: "bg-primary"

  defp format_limit(limit) when limit >= 1_000_000, do: "#{Float.round(limit / 1_000_000, 1)}M"
  defp format_limit(limit) when limit >= 1_000, do: "#{div(limit, 1_000)}K"
  defp format_limit(limit), do: "#{limit}"

  defp beginning_of_month do
    today = Date.utc_today()
    {:ok, dt} = NaiveDateTime.new(today.year, today.month, 1, 0, 0, 0)
    DateTime.from_naive!(dt, "Etc/UTC")
  end

  defp get_user_org_id(nil), do: nil

  defp get_user_org_id(user) do
    case user |> Ash.load!(:organisations) |> Map.get(:organisations) do
      [org | _] -> org.id
      _ -> nil
    end
  end

  defp get_org_plan(nil), do: nil

  defp get_org_plan(org_id) do
    case FounderPad.Billing.Subscription
         |> Ash.Query.filter(organisation_id == ^org_id and status == :active)
         |> Ash.Query.load([:plan])
         |> Ash.read!() do
      [sub | _] -> sub.plan
      [] -> nil
    end
  end

  defp load_usage_history(nil), do: []

  defp load_usage_history(org_id) do
    FounderPad.Billing.UsageRecord
    |> Ash.Query.filter(organisation_id == ^org_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(50)
    |> Ash.read!()
  end
end
