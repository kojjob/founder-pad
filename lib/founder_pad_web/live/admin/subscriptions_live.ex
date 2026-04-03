defmodule FounderPadWeb.Admin.SubscriptionsLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    subscriptions =
      FounderPad.Billing.Subscription
      |> Ash.Query.load([:organisation, :plan])
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!()

    {:ok,
     assign(socket,
       page_title: "Subscriptions \u2014 Admin",
       active_nav: :admin_subs,
       subscriptions: subscriptions
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
            Subscriptions
          </h1>
          <p class="text-on-surface-variant mt-2">
            View all organisation subscriptions and their billing status.
          </p>
        </div>
      </div>

      <div class="bg-surface-container rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Organisation
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Plan
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Status
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Period End
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Auto-Renew
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={sub <- @subscriptions}
              class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
            >
              <td class="px-6 py-4">
                <div class="font-medium text-on-surface">{sub.organisation.name}</div>
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {sub.plan.name}
              </td>
              <td class="px-6 py-4">
                <.status_badge status={sub.status} />
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {if sub.current_period_end,
                  do: Calendar.strftime(sub.current_period_end, "%b %d, %Y"),
                  else: "\u2014"}
              </td>
              <td class="px-6 py-4">
                <span
                  :if={sub.cancel_at_period_end}
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700"
                >
                  Canceling
                </span>
                <span
                  :if={!sub.cancel_at_period_end}
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700"
                >
                  Active
                </span>
              </td>
            </tr>
          </tbody>
        </table>

        <div
          :if={@subscriptions == []}
          class="px-6 py-16 text-center text-on-surface-variant"
        >
          <span class="material-symbols-outlined text-4xl opacity-30 block mb-2">credit_card</span>
          <p>No subscriptions found.</p>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge(assigns) do
    {bg, text} =
      case assigns.status do
        :active -> {"bg-green-100 text-green-700", "Active"}
        :trialing -> {"bg-blue-100 text-blue-700", "Trialing"}
        :past_due -> {"bg-red-100 text-red-700", "Past Due"}
        :canceled -> {"bg-neutral-100 text-neutral-600", "Canceled"}
        :incomplete -> {"bg-amber-100 text-amber-700", "Incomplete"}
        :unpaid -> {"bg-red-100 text-red-700", "Unpaid"}
        _ -> {"bg-neutral-100 text-neutral-600", "Unknown"}
      end

    assigns = assign(assigns, bg: bg, text: text)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@bg}"}>
      {@text}
    </span>
    """
  end
end
