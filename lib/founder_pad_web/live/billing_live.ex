defmodule FounderPadWeb.BillingLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_nav: :billing,
       page_title: "Billing",
       current_plan: %{name: "Pro", price: "$79/mo", renewal: "Apr 15, 2026"},
       usage: %{
         api_calls: 45_200,
         limit: 100_000,
         agents: 12,
         agent_limit: 50,
         seats: 8,
         seat_limit: 20
       },
       invoices: [
         %{date: "Mar 1, 2026", amount: "$79.00", status: :paid, id: "INV-2026-003"},
         %{date: "Feb 1, 2026", amount: "$79.00", status: :paid, id: "INV-2026-002"},
         %{date: "Jan 1, 2026", amount: "$29.00", status: :paid, id: "INV-2026-001"}
       ]
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <section>
        <h1 class="text-4xl font-extrabold font-headline tracking-tight">
          Billing &amp; Subscriptions
        </h1>
        <p class="text-on-surface-variant mt-1">Manage your plan, usage, and payment methods</p>
      </section>

      <%!-- Current Plan --%>
      <section class="bg-gradient-to-br from-surface-container to-surface-container-high rounded-lg p-8 border border-outline-variant/10">
        <div class="flex items-start justify-between">
          <div>
            <p class="text-xs font-mono text-on-surface-variant uppercase tracking-wider mb-2">
              Current Plan
            </p>
            <h2 class="text-3xl font-bold font-headline">{@current_plan.name}</h2>
            <p class="text-on-surface-variant mt-1">
              {@current_plan.price} &bull; Renews {@current_plan.renewal}
            </p>
          </div>
          <button class="bg-gradient-to-br from-primary to-primary-container text-on-primary-fixed font-semibold px-5 py-2.5 rounded-lg text-sm">
            Upgrade Plan
          </button>
        </div>
      </section>

      <%!-- Usage Meters --%>
      <section class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <.usage_meter label="API Calls" used={@usage.api_calls} limit={@usage.limit} color="primary" />
        <.usage_meter
          label="Active Agents"
          used={@usage.agents}
          limit={@usage.agent_limit}
          color="secondary"
        />
        <.usage_meter
          label="Team Seats"
          used={@usage.seats}
          limit={@usage.seat_limit}
          color="primary"
        />
      </section>

      <%!-- Invoice History --%>
      <section class="space-y-4">
        <h2 class="text-2xl font-bold font-headline">Invoice History</h2>
        <div class="bg-surface-container rounded-lg overflow-hidden">
          <div class="grid grid-cols-4 gap-4 px-6 py-3 text-xs font-mono uppercase tracking-widest text-on-surface-variant border-b border-outline-variant/10">
            <div>Invoice</div>
            <div>Date</div>
            <div>Amount</div>
            <div>Status</div>
          </div>
          <div
            :for={inv <- @invoices}
            class="grid grid-cols-4 gap-4 px-6 py-4 hover:bg-surface-container-high/50 transition-colors"
          >
            <div class="font-mono text-sm text-primary">{inv.id}</div>
            <div class="text-sm text-on-surface-variant">{inv.date}</div>
            <div class="font-mono text-sm">{inv.amount}</div>
            <div>
              <span class="px-2 py-0.5 rounded-full bg-green-500/10 text-green-400 text-[10px] font-bold">
                Paid
              </span>
            </div>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp usage_meter(assigns) do
    pct = if assigns.limit > 0, do: round(assigns.used / assigns.limit * 100), else: 0
    assigns = assign(assigns, :pct, pct)

    ~H"""
    <div class="bg-surface-container p-6 rounded-lg">
      <div class="flex justify-between items-start mb-4">
        <p class="text-sm font-medium text-on-surface-variant">{@label}</p>
        <span class="text-xs font-mono text-on-surface-variant">{@pct}%</span>
      </div>
      <p class="text-2xl font-mono font-medium mb-4">
        <span class={"text-#{@color}"}>{Integer.to_string(@used)}</span>
        <span class="text-on-surface-variant text-sm"> / {Integer.to_string(@limit)}</span>
      </p>
      <div class="h-1.5 w-full bg-surface-container-highest rounded-full overflow-hidden">
        <div class={"h-full bg-#{@color} rounded-full"} style={"width: #{@pct}%"}></div>
      </div>
    </div>
    """
  end
end
