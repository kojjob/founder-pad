defmodule FounderPadWeb.BillingLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_nav: :billing,
       page_title: "Billing & Subscriptions",
       current_plan: %{
         name: "Pro Architect",
         price: "$149.00",
         features: [
           "Unlimited AI Agents",
           "Advanced Vector Memory",
           "Priority API Access"
         ]
       },
       usage: %{
         compute_display: "842 / 1,000",
         compute_pct: 84,
         token_display: "42.8M / 50M",
         token_pct: 72
       },
       payment: %{
         last_four: "4242",
         expires: "12/26",
         card_brand_url:
           "https://lh3.googleusercontent.com/aida-public/AB6AXuAdIbYvYXROtzz3HZi6QmrymKu3sjiTdmGI0kj66ftyjxnufE0Hth9ey0PyW0R7af1D2JPqQnwugZB7Nm0n_BLQUC80o6JR81QKdgUSDR2goTVPe1E76EowLp1_3XGnN5KA9wyFwKEF4lEQfMp9LFiydx6L2squRqXGQw0-cBMjG28J2Qbrvqd9tJ-lNKsvgiz1Rv72vUyxF1garZ8GKm7I2EkoqGPRo2vO8QXN84_P9_laPVKc4LvNe3jOy4A2fc3qAp4bApIxxA"
       },
       billing_contact: %{
         legal_entity: "Midnight Digital Labs Inc.",
         email: "accounts@midnight-architect.ai"
       },
       invoices: [
         %{id: "INV-2024-009", date: "Oct 12, 2024", amount: "$149.00", status: :paid},
         %{id: "INV-2024-008", date: "Sep 12, 2024", amount: "$149.00", status: :paid},
         %{id: "INV-2024-007", date: "Aug 12, 2024", amount: "$149.00", status: :paid},
         %{id: "INV-2024-006", date: "Jul 12, 2024", amount: "$89.00", status: :paid}
       ]
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-10">
      <%!-- Hero Section: Current Plan & Usage --%>
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        <%!-- Current Plan Card --%>
        <div class="lg:col-span-5 bg-surface-container-high rounded-xl p-8 border border-outline-variant/10 relative overflow-hidden">
          <div class="absolute top-0 right-0 w-32 h-32 bg-primary/5 rounded-full -mr-16 -mt-16 blur-3xl">
          </div>
          <div class="relative z-10">
            <div class="flex justify-between items-start mb-6">
              <div>
                <span class="text-[10px] uppercase tracking-widest text-primary font-bold mb-1 block">
                  Current Plan
                </span>
                <h2 class="text-3xl font-extrabold text-on-surface font-headline italic">
                  {@current_plan.name}
                </h2>
              </div>
              <span class="bg-primary/10 text-primary text-xs font-bold px-3 py-1 rounded-full border border-primary/20">
                Active
              </span>
            </div>
            <div class="space-y-4 mb-8">
              <div
                :for={feature <- @current_plan.features}
                class="flex items-center gap-3 text-on-surface-variant text-sm"
              >
                <span
                  class="material-symbols-outlined text-primary text-lg"
                  style="font-variation-settings: 'FILL' 1;"
                >
                  check_circle
                </span>
                <span>{feature}</span>
              </div>
            </div>
            <div class="pt-6 border-t border-outline-variant/20 flex flex-col gap-4">
              <div class="flex justify-between items-baseline">
                <span class="text-on-surface-variant text-sm">Monthly Cost</span>
                <span class="font-mono text-2xl font-bold text-on-surface">
                  {@current_plan.price}
                </span>
              </div>
              <button class="w-full primary-gradient text-on-primary-fixed font-bold py-3 rounded-lg flex items-center justify-center gap-2 hover:shadow-[0_0_20px_rgba(128,131,255,0.3)] transition-all">
                <span>Upgrade Plan</span>
                <span class="material-symbols-outlined">rocket_launch</span>
              </button>
            </div>
          </div>
        </div>
        <%!-- Usage Meters --%>
        <div class="lg:col-span-7 grid grid-cols-1 sm:grid-cols-2 gap-4">
          <%!-- Compute Hours --%>
          <div class="bg-surface-container rounded-xl p-6 flex flex-col justify-between h-48 border border-outline-variant/5">
            <div class="flex justify-between items-start">
              <div>
                <p class="text-xs text-on-surface-variant font-medium">Compute Hours</p>
                <p class="text-2xl font-bold font-mono">{@usage.compute_display}</p>
              </div>
              <span class="material-symbols-outlined text-secondary opacity-50">speed</span>
            </div>
            <div class="space-y-2">
              <div class="w-full h-3 bg-surface-container-highest rounded-full overflow-hidden">
                <div class={"h-full bg-secondary rounded-full w-[#{@usage.compute_pct}%]"}></div>
              </div>
              <p class="text-[10px] text-on-surface-variant">Resetting in 12 days</p>
            </div>
          </div>
          <%!-- Token Processing --%>
          <div class="bg-surface-container rounded-xl p-6 flex flex-col justify-between h-48 border border-outline-variant/5">
            <div class="flex justify-between items-start">
              <div>
                <p class="text-xs text-on-surface-variant font-medium">Token Processing</p>
                <p class="text-2xl font-bold font-mono">{@usage.token_display}</p>
              </div>
              <span class="material-symbols-outlined text-secondary opacity-50">
                data_thresholding
              </span>
            </div>
            <div class="space-y-2">
              <div class="w-full h-3 bg-surface-container-highest rounded-full overflow-hidden">
                <div class={"h-full bg-secondary rounded-full w-[#{@usage.token_pct}%]"}></div>
              </div>
              <p class="text-[10px] text-on-surface-variant">85.6% of limit reached</p>
            </div>
          </div>
          <%!-- Usage Warning --%>
          <div class="sm:col-span-2 bg-surface-container rounded-xl p-6 border border-outline-variant/5">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class="p-2 bg-secondary/10 rounded-lg">
                  <span class="material-symbols-outlined text-secondary">warning</span>
                </div>
                <div>
                  <h4 class="font-bold text-sm">Approaching Usage Limit</h4>
                  <p class="text-xs text-on-surface-variant">
                    You've used 84% of your monthly compute hours.
                  </p>
                </div>
              </div>
              <button class="text-sm font-semibold text-secondary hover:underline">
                Enable Auto-Refill
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Middle Row: Payment & Billing Contact --%>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%!-- Payment Method Card --%>
        <div class="bg-surface-container-low border border-outline-variant/20 rounded-xl p-6 flex flex-col justify-between">
          <div>
            <div class="flex justify-between items-center mb-6">
              <h3 class="text-sm font-bold uppercase tracking-wider text-on-surface-variant">
                Payment Method
              </h3>
              <button class="text-xs font-semibold text-primary hover:text-white">Update</button>
            </div>
            <div class="flex items-center gap-4 bg-surface-container-highest/30 p-4 rounded-lg border border-outline-variant/10">
              <div class="w-12 h-8 bg-[#1a1a1a] rounded flex items-center justify-center border border-white/5">
                <img class="h-4 opacity-80" alt="Card brand" src={@payment.card_brand_url} />
              </div>
              <div>
                <p class="font-mono text-sm tracking-widest text-on-surface">
                  &bull;&bull;&bull;&bull; &bull;&bull;&bull;&bull; &bull;&bull;&bull;&bull; {@payment.last_four}
                </p>
                <p class="text-[10px] text-on-surface-variant uppercase">
                  Expires {@payment.expires}
                </p>
              </div>
            </div>
          </div>
          <div class="mt-8 flex items-center gap-2 text-xs text-on-surface-variant">
            <span class="material-symbols-outlined text-sm">lock</span>
            <p>Secure PCI-compliant billing provided by Stripe</p>
          </div>
        </div>
        <%!-- Billing Contact --%>
        <div class="bg-surface-container-low border border-outline-variant/20 rounded-xl p-6">
          <div class="flex justify-between items-center mb-6">
            <h3 class="text-sm font-bold uppercase tracking-wider text-on-surface-variant">
              Billing Contact
            </h3>
            <button class="text-xs font-semibold text-primary hover:text-white">Edit</button>
          </div>
          <div class="space-y-4">
            <div>
              <label class="text-[10px] text-on-surface-variant font-bold uppercase mb-1 block">
                Legal Entity
              </label>
              <p class="text-sm font-medium">{@billing_contact.legal_entity}</p>
            </div>
            <div>
              <label class="text-[10px] text-on-surface-variant font-bold uppercase mb-1 block">
                Invoicing Email
              </label>
              <p class="text-sm font-medium">{@billing_contact.email}</p>
            </div>
            <div class="pt-4 flex items-center gap-3">
              <button class="text-xs bg-surface-container-highest px-3 py-1.5 rounded-md hover:bg-surface-bright transition-colors">
                VAT/Tax ID Settings
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Invoice History Table --%>
      <div class="space-y-4">
        <div class="flex justify-between items-end px-2">
          <div>
            <h3 class="text-xl font-bold font-headline">Invoice History</h3>
            <p class="text-xs text-on-surface-variant">
              View and download your past subscription receipts.
            </p>
          </div>
          <button class="text-xs font-semibold border border-outline-variant/20 px-4 py-2 rounded-lg hover:bg-surface-container transition-colors">
            Export All (CSV)
          </button>
        </div>
        <div class="bg-surface-container rounded-xl overflow-hidden border border-outline-variant/10">
          <div class="overflow-x-auto">
            <table class="w-full text-left border-collapse">
              <thead>
                <tr class="bg-surface-container-highest/30">
                  <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
                    Invoice ID
                  </th>
                  <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
                    Date
                  </th>
                  <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
                    Amount
                  </th>
                  <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">
                    Status
                  </th>
                  <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-on-surface-variant text-right">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-outline-variant/5">
                <tr
                  :for={inv <- @invoices}
                  class="hover:bg-surface-container-high transition-colors group"
                >
                  <td class="px-6 py-4 font-mono text-sm text-on-surface-variant">{inv.id}</td>
                  <td class="px-6 py-4 text-sm font-medium">{inv.date}</td>
                  <td class="px-6 py-4 font-mono text-sm">{inv.amount}</td>
                  <td class="px-6 py-4">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-secondary/10 text-secondary border border-secondary/20">
                      Paid
                    </span>
                  </td>
                  <td class="px-6 py-4 text-right">
                    <div class="flex justify-end gap-3">
                      <button class="text-primary hover:text-white transition-colors">
                        <span class="material-symbols-outlined text-[20px]">visibility</span>
                      </button>
                      <button class="text-primary hover:text-white transition-colors">
                        <span class="material-symbols-outlined text-[20px]">download</span>
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="bg-surface-container-lowest/50 px-6 py-3 flex justify-center border-t border-outline-variant/10">
            <button class="text-xs text-on-surface-variant hover:text-on-surface font-medium transition-colors">
              Load more invoices...
            </button>
          </div>
        </div>
      </div>

      <%!-- Danger Zone --%>
      <div class="pt-10">
        <div class="p-6 bg-error-container/10 border border-error-container/20 rounded-xl flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h4 class="font-bold text-error">Cancel Subscription</h4>
            <p class="text-xs text-on-surface-variant">
              Immediate access will be revoked at the end of your billing cycle.
            </p>
          </div>
          <button class="px-4 py-2 border border-error/30 text-error text-xs font-bold rounded-lg hover:bg-error/10 transition-all uppercase tracking-widest">
            Terminate Plan
          </button>
        </div>
      </div>
    </div>
    """
  end
end
