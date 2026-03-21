defmodule FounderPadWeb.BillingLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(params, _session, socket) do
    plans = load_plans()
    current_plan = find_current_plan(plans)
    user = socket.assigns[:current_user]
    org_id = get_user_org_id(user)
    plan_resource = Enum.find(plans, List.first(plans), &(&1.slug == current_plan.slug))
    usage = load_usage(org_id, plan_resource)
    invoices = load_invoices(org_id)

    socket =
      socket
      |> assign(
        active_nav: :billing,
        page_title: "Billing & Subscriptions",
        plans: plans,
        current_plan: current_plan,
        usage: usage,
        invoices: invoices,
        org_id: org_id,
        payment: %{last_four: "4242", expires: "12/26"},
        billing_contact: %{
          legal_entity: if(user, do: "#{user.name || "Your"} Organization", else: "Your Organization"),
          email: if(user, do: to_string(user.email), else: "billing@company.com")
        },
        editing_contact: false,
        contact_form: %{"legal_entity" => "", "email" => ""},
        show_cancel_confirm: false
      )

    # Handle checkout return params
    socket =
      cond do
        params["success"] == "true" ->
          put_flash(socket, :info, "Subscription activated successfully!")

        params["canceled"] == "true" ->
          put_flash(socket, :error, "Checkout was canceled.")

        params["checkout"] == "simulated" ->
          put_flash(socket, :info, "Simulated checkout for #{params["plan"]} plan (Stripe not configured)")

        true ->
          socket
      end

    {:ok, socket}
  end

  # ── Data Loading ──

  defp load_plans do
    case FounderPad.Billing.Plan |> Ash.Query.sort(sort_order: :asc) |> Ash.read() do
      {:ok, plans} -> plans
      _ -> []
    end
  end

  defp find_current_plan(plans) do
    # Find the plan the org is subscribed to, or default to first plan
    plan = Enum.find(plans, List.first(plans), &(&1.slug == "pro"))

    if plan do
      price = plan.price_cents / 100

      %{
        name: plan.name,
        slug: plan.slug,
        price: "$#{:erlang.float_to_binary(price / 1, decimals: 2)}",
        features:
          if(plan.features != [],
            do: plan.features,
            else: [
              "#{plan.max_agents} AI Agents",
              "#{plan.max_seats} Team Seats",
              "#{format_number(plan.max_api_calls_per_month)} API Calls/mo"
            ]
          )
      }
    else
      %{name: "Free", slug: "free", price: "$0.00", features: ["Basic access"]}
    end
  end

  defp load_usage(org_id, plan) do
    usage = count_org_usage(org_id)
    agents = count_org_agents(org_id)
    api_limit = if(plan, do: plan.max_api_calls_per_month, else: 1000)
    agents_limit = if(plan, do: plan.max_agents, else: 3)

    %{
      compute_used: usage,
      compute_limit: api_limit,
      compute_display: "#{usage} / #{format_number(api_limit)}",
      compute_pct: usage_pct(usage, api_limit),
      agents_used: agents,
      agents_limit: agents_limit,
      token_used: usage * 500,
      token_limit: api_limit * 500,
      token_display: "#{format_number(usage * 500)} / #{format_number(api_limit * 500)}",
      token_pct: usage_pct(usage * 500, api_limit * 500)
    }
  end

  defp count_org_usage(nil), do: 0

  defp count_org_usage(org_id) do
    case FounderPad.Billing.UsageRecord
         |> Ash.Query.filter(organisation_id: org_id)
         |> Ash.count() do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp count_org_agents(nil), do: 0

  defp count_org_agents(org_id) do
    case FounderPad.AI.Agent
         |> Ash.Query.filter(organisation_id: org_id)
         |> Ash.count() do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp load_invoices(nil), do: []

  defp load_invoices(org_id) do
    case FounderPad.Billing.Invoice
         |> Ash.Query.filter(organisation_id: org_id)
         |> Ash.Query.sort(period_start: :desc)
         |> Ash.Query.limit(10)
         |> Ash.read() do
      {:ok, invs} -> Enum.map(invs, &format_invoice/1)
      _ -> []
    end
  end

  defp format_invoice(inv) do
    %{
      id: inv.invoice_number,
      date:
        if(inv.period_start,
          do: Calendar.strftime(inv.period_start, "%b %d, %Y"),
          else: "—"
        ),
      amount: "$#{:erlang.float_to_binary(inv.amount_cents / 100, decimals: 2)}",
      status: inv.status
    }
  end

  defp get_user_org_id(nil), do: nil

  defp get_user_org_id(user) do
    case FounderPad.Accounts.Membership
         |> Ash.Query.filter(user_id: user.id)
         |> Ash.Query.limit(1)
         |> Ash.read() do
      {:ok, [membership | _]} -> membership.organisation_id
      _ -> nil
    end
  end

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 0) |> trunc()}K"
  defp format_number(n), do: "#{n}"

  defp usage_pct(used, limit) when limit > 0, do: min(round(used / limit * 100), 100)
  defp usage_pct(_, _), do: 0

  # ── Event Handlers ──

  def handle_event("edit_contact", _, socket) do
    {:noreply,
     assign(socket,
       editing_contact: true,
       contact_form: %{
         "legal_entity" => socket.assigns.billing_contact.legal_entity,
         "email" => socket.assigns.billing_contact.email
       }
     )}
  end

  def handle_event("cancel_edit_contact", _, socket) do
    {:noreply, assign(socket, editing_contact: false)}
  end

  def handle_event("save_contact", %{"contact" => params}, socket) do
    {:noreply,
     socket
     |> assign(
       billing_contact: %{
         legal_entity: params["legal_entity"] || socket.assigns.billing_contact.legal_entity,
         email: params["email"] || socket.assigns.billing_contact.email
       },
       editing_contact: false
     )
     |> put_flash(:info, "Billing contact updated")}
  end

  def handle_event("toggle_cancel_confirm", _, socket) do
    {:noreply, assign(socket, show_cancel_confirm: !socket.assigns.show_cancel_confirm)}
  end

  def handle_event("confirm_cancel", _, socket) do
    # In production, call Stripe to cancel the subscription
    {:noreply,
     socket
     |> assign(show_cancel_confirm: false)
     |> put_flash(:info, "Subscription will be canceled at the end of the billing period")}
  end

  def handle_event("enable_auto_refill", _, socket) do
    {:noreply, put_flash(socket, :info, "Auto-refill enabled for compute hours")}
  end

  def handle_event("export_invoices", _, socket) do
    {:noreply, put_flash(socket, :info, "Invoice CSV export started — check your email")}
  end

  def handle_event("view_invoice", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "Opening invoice #{id}...")}
  end

  def handle_event("download_invoice", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "Downloading #{id}.pdf...")}
  end

  def handle_event("update_payment", _, socket) do
    {:noreply, put_flash(socket, :info, "Stripe payment method update coming soon")}
  end

  # ── Render ──

  def render(assigns) do
    assigns =
      assigns
      |> assign(:compute_pct, usage_pct(assigns.usage.compute_used, assigns.usage.compute_limit))
      |> assign(:token_pct, usage_pct(assigns.usage.token_used, assigns.usage.token_limit))

    ~H"""
    <div class="space-y-10">
      <%!-- Hero Section: Current Plan & Usage --%>
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        <%!-- Current Plan Card --%>
        <div class="lg:col-span-5 bg-surface-container-high rounded-xl p-8 relative overflow-hidden">
          <div class="absolute top-0 right-0 w-32 h-32 bg-primary/5 rounded-full -mr-16 -mt-16 blur-3xl"></div>
          <div class="relative z-10">
            <div class="flex justify-between items-start mb-6">
              <div>
                <span class="text-[10px] uppercase tracking-widest text-primary font-bold mb-1 block">Current Plan</span>
                <h2 class="text-3xl font-extrabold text-on-surface font-headline italic">{@current_plan.name}</h2>
              </div>
              <span class="bg-primary/10 text-primary text-xs font-bold px-3 py-1 rounded-full">Active</span>
            </div>
            <div class="space-y-4 mb-8">
              <div :for={feature <- @current_plan.features} class="flex items-center gap-3 text-on-surface-variant text-sm">
                <span class="material-symbols-outlined text-primary text-lg" style="font-variation-settings: 'FILL' 1;">check_circle</span>
                <span>{feature}</span>
              </div>
            </div>
            <div class="pt-6 space-y-4">
              <div class="flex justify-between items-baseline">
                <span class="text-on-surface-variant text-sm">Monthly Cost</span>
                <span class="font-mono text-2xl font-bold text-on-surface">{@current_plan.price}</span>
              </div>
              <%!-- Dynamic upgrade: pick next tier --%>
              <form method="post" action={"/checkout/#{next_plan_slug(@current_plan.slug, @plans)}"}>
                <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
                <button type="submit" class="w-full primary-gradient font-bold py-3 rounded-lg flex items-center justify-center gap-2 hover:scale-[1.01] transition-transform">
                  <span>Upgrade Plan</span>
                  <span class="material-symbols-outlined">rocket_launch</span>
                </button>
              </form>
            </div>
          </div>
        </div>

        <%!-- Usage Meters (dynamic) --%>
        <div class="lg:col-span-7 grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div class="bg-surface-container rounded-xl p-6 flex flex-col justify-between h-48">
            <div class="flex justify-between items-start">
              <div>
                <p class="text-xs text-on-surface-variant font-medium">Compute Hours</p>
                <p class="text-2xl font-bold font-mono">{@usage.compute_used} / {format_number(@usage.compute_limit)}</p>
              </div>
              <span class="material-symbols-outlined text-secondary opacity-50">speed</span>
            </div>
            <div class="space-y-2">
              <div class="w-full h-3 bg-surface-container-highest rounded-full overflow-hidden">
                <div class={"h-full bg-secondary rounded-full transition-all duration-500"} style={"width: #{@compute_pct}%"}></div>
              </div>
              <p class="text-[10px] text-on-surface-variant">{@compute_pct}% used • Resets in 12 days</p>
            </div>
          </div>

          <div class="bg-surface-container rounded-xl p-6 flex flex-col justify-between h-48">
            <div class="flex justify-between items-start">
              <div>
                <p class="text-xs text-on-surface-variant font-medium">Token Processing</p>
                <p class="text-2xl font-bold font-mono">{format_number(@usage.token_used)} / {format_number(@usage.token_limit)}</p>
              </div>
              <span class="material-symbols-outlined text-secondary opacity-50">data_thresholding</span>
            </div>
            <div class="space-y-2">
              <div class="w-full h-3 bg-surface-container-highest rounded-full overflow-hidden">
                <div class={"h-full bg-secondary rounded-full transition-all duration-500"} style={"width: #{@token_pct}%"}></div>
              </div>
              <p class="text-[10px] text-on-surface-variant">{@token_pct}% of limit reached</p>
            </div>
          </div>

          <div :if={@compute_pct >= 70} class="sm:col-span-2 bg-surface-container rounded-xl p-6">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class="p-2 bg-secondary/10 rounded-lg">
                  <span class="material-symbols-outlined text-secondary">warning</span>
                </div>
                <div>
                  <h4 class="font-bold text-sm">Approaching Usage Limit</h4>
                  <p class="text-xs text-on-surface-variant">You've used {@compute_pct}% of your monthly compute hours.</p>
                </div>
              </div>
              <button phx-click="enable_auto_refill" class="text-sm font-semibold text-secondary hover:underline">Enable Auto-Refill</button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Middle Row: Payment & Billing Contact --%>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%!-- Payment Method --%>
        <div class="bg-surface-container-low rounded-xl p-6 flex flex-col justify-between">
          <div>
            <div class="flex justify-between items-center mb-6">
              <h3 class="text-sm font-bold uppercase tracking-wider text-on-surface-variant">Payment Method</h3>
              <button phx-click="update_payment" class="text-xs font-semibold text-primary hover:underline">Update</button>
            </div>
            <div class="flex items-center gap-4 bg-surface-container-highest/30 p-4 rounded-lg">
              <div class="w-12 h-8 bg-surface-container-highest rounded flex items-center justify-center">
                <span class="material-symbols-outlined text-on-surface-variant text-lg">credit_card</span>
              </div>
              <div>
                <p class="font-mono text-sm tracking-widest text-on-surface">•••• •••• •••• {@payment.last_four}</p>
                <p class="text-[10px] text-on-surface-variant uppercase">Expires {@payment.expires}</p>
              </div>
            </div>
          </div>
          <div class="mt-8 flex items-center gap-2 text-xs text-on-surface-variant">
            <span class="material-symbols-outlined text-sm">lock</span>
            <p>Secure PCI-compliant billing provided by Stripe</p>
          </div>
        </div>

        <%!-- Billing Contact (editable) --%>
        <div class="bg-surface-container-low rounded-xl p-6">
          <div class="flex justify-between items-center mb-6">
            <h3 class="text-sm font-bold uppercase tracking-wider text-on-surface-variant">Billing Contact</h3>
            <button :if={!@editing_contact} phx-click="edit_contact" class="text-xs font-semibold text-primary hover:underline">Edit</button>
            <button :if={@editing_contact} phx-click="cancel_edit_contact" class="text-xs font-semibold text-on-surface-variant hover:underline">Cancel</button>
          </div>

          <%!-- View mode --%>
          <div :if={!@editing_contact} class="space-y-4">
            <div>
              <label class="text-[10px] text-on-surface-variant font-bold uppercase mb-1 block">Legal Entity</label>
              <p class="text-sm font-medium">{@billing_contact.legal_entity}</p>
            </div>
            <div>
              <label class="text-[10px] text-on-surface-variant font-bold uppercase mb-1 block">Invoicing Email</label>
              <p class="text-sm font-medium">{@billing_contact.email}</p>
            </div>
            <div class="pt-4">
              <button class="text-xs bg-surface-container-highest px-3 py-1.5 rounded-md hover:bg-surface-bright transition-colors">VAT/Tax ID Settings</button>
            </div>
          </div>

          <%!-- Edit mode --%>
          <.form :if={@editing_contact} for={%{}} as={:contact} phx-submit="save_contact" class="space-y-4">
            <div>
              <label class="text-[10px] text-on-surface-variant font-bold uppercase mb-1 block">Legal Entity</label>
              <input type="text" name="contact[legal_entity]" value={@billing_contact.legal_entity} class="w-full bg-surface-container-highest rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary" />
            </div>
            <div>
              <label class="text-[10px] text-on-surface-variant font-bold uppercase mb-1 block">Invoicing Email</label>
              <input type="email" name="contact[email]" value={@billing_contact.email} class="w-full bg-surface-container-highest rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary" />
            </div>
            <button type="submit" class="primary-gradient font-semibold px-4 py-2 rounded-lg text-sm">Save Contact</button>
          </.form>
        </div>
      </div>

      <%!-- Invoice History --%>
      <div class="space-y-4">
        <div class="flex justify-between items-end px-2">
          <div>
            <h3 class="text-xl font-bold font-headline">Invoice History</h3>
            <p class="text-xs text-on-surface-variant">View and download your past subscription receipts.</p>
          </div>
          <button phx-click="export_invoices" class="text-xs font-semibold bg-surface-container-high px-4 py-2 rounded-lg hover:bg-surface-container-highest transition-colors flex items-center gap-2">
            <span class="material-symbols-outlined text-sm">download</span>
            Export All (CSV)
          </button>
        </div>
        <div class="bg-surface-container rounded-xl overflow-hidden">
          <table class="w-full text-left border-collapse">
            <thead>
              <tr class="bg-surface-container-highest/30">
                <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">Invoice ID</th>
                <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">Date</th>
                <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">Amount</th>
                <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-on-surface-variant">Status</th>
                <th class="px-6 py-4 text-[10px] font-bold uppercase tracking-widest text-on-surface-variant text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr :if={@invoices == []} >
                <td colspan="5" class="px-6 py-12 text-center text-on-surface-variant text-sm">
                  <span class="material-symbols-outlined text-3xl mb-2 block opacity-40">receipt_long</span>
                  No invoices yet
                </td>
              </tr>
              <tr :for={inv <- @invoices} class="hover:bg-surface-container-high transition-colors group">
                <td class="px-6 py-4 font-mono text-sm text-on-surface-variant">{inv.id}</td>
                <td class="px-6 py-4 text-sm font-medium">{inv.date}</td>
                <td class="px-6 py-4 font-mono text-sm">{inv.amount}</td>
                <td class="px-6 py-4">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-secondary/10 text-secondary">Paid</span>
                </td>
                <td class="px-6 py-4 text-right">
                  <div class="flex justify-end gap-3 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button phx-click="view_invoice" phx-value-id={inv.id} class="text-primary hover:text-on-surface transition-colors" title="View">
                      <span class="material-symbols-outlined text-[20px]">visibility</span>
                    </button>
                    <button phx-click="download_invoice" phx-value-id={inv.id} class="text-primary hover:text-on-surface transition-colors" title="Download PDF">
                      <span class="material-symbols-outlined text-[20px]">download</span>
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
          <div :if={length(@invoices) >= 3} class="bg-surface-container-lowest/50 px-6 py-3 flex justify-center">
            <button class="text-xs text-on-surface-variant hover:text-on-surface font-medium transition-colors">Load more invoices...</button>
          </div>
        </div>
      </div>

      <%!-- Cancel Subscription --%>
      <div class="pt-10">
        <div class="p-6 bg-error-container/10 rounded-xl flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h4 class="font-bold text-error">Cancel Subscription</h4>
            <p class="text-xs text-on-surface-variant">Immediate access will be revoked at the end of your billing cycle.</p>
          </div>
          <div :if={!@show_cancel_confirm}>
            <button phx-click="toggle_cancel_confirm" class="px-4 py-2 text-error text-xs font-bold rounded-lg hover:bg-error/10 transition-all uppercase tracking-widest bg-surface-container-highest">
              Terminate Plan
            </button>
          </div>
          <div :if={@show_cancel_confirm} class="flex items-center gap-3">
            <span class="text-xs text-error font-medium">Are you sure?</span>
            <button phx-click="confirm_cancel" class="px-4 py-2 bg-error text-on-error text-xs font-bold rounded-lg uppercase tracking-widest">Yes, Cancel</button>
            <button phx-click="toggle_cancel_confirm" class="px-4 py-2 bg-surface-container-highest text-on-surface-variant text-xs font-bold rounded-lg">Keep Plan</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp next_plan_slug(current_slug, plans) do
    slugs = Enum.map(plans, & &1.slug)
    current_idx = Enum.find_index(slugs, &(&1 == current_slug)) || 0
    Enum.at(slugs, current_idx + 1, List.last(slugs) || "enterprise")
  end
end
