defmodule FounderPadWeb.ReferralsLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]
    referrals = load_referrals(user)
    referral_code = get_or_create_referral_code(user)
    total_earned = calculate_total_earned(referrals)

    {:ok,
     assign(socket,
       active_nav: :referrals,
       page_title: "Referrals",
       referrals: referrals,
       referral_code: referral_code,
       total_earned: total_earned
     )}
  end

  def handle_event("generate_code", _, socket) do
    user = socket.assigns[:current_user]

    case FounderPad.Referrals.Referral
         |> Ash.Changeset.for_create(:create, %{referrer_id: user.id})
         |> Ash.create() do
      {:ok, referral} ->
        referrals = load_referrals(user)
        {:noreply, assign(socket, referral_code: referral.code, referrals: referrals)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to generate referral code")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-5xl mx-auto">
      <div>
        <h1 class="text-3xl font-extrabold font-headline tracking-tight text-on-surface">
          Referrals
        </h1>
        <p class="text-on-surface-variant mt-1">Invite others and earn rewards</p>
      </div>

      <%!-- Referral Code Section --%>
      <div class="bg-surface-container rounded-2xl p-6 space-y-4">
        <h2 class="text-lg font-bold text-on-surface">Your Referral Code</h2>
        <%= if @referral_code do %>
          <div class="flex items-center gap-4">
            <div class="bg-surface-container-high rounded-xl px-6 py-3 font-mono text-xl font-bold text-primary tracking-wider">
              {@referral_code}
            </div>
            <button
              phx-click={JS.dispatch("phx:copy", to: "#referral-link")}
              class="px-4 py-2.5 bg-primary text-on-primary rounded-lg text-sm font-semibold hover:bg-primary/90 transition-colors"
            >
              Copy Link
            </button>
          </div>
          <div id="referral-link" class="text-sm text-on-surface-variant font-mono">
            {FounderPadWeb.Endpoint.url()}/auth/register?ref={@referral_code}
          </div>
        <% else %>
          <button
            phx-click="generate_code"
            class="px-5 py-2.5 primary-gradient rounded-lg text-sm font-semibold"
          >
            Generate Referral Code
          </button>
        <% end %>
      </div>

      <%!-- Stats --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-surface-container p-6 rounded-2xl">
          <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2">
            Total Referrals
          </p>
          <p class="text-3xl font-mono font-medium text-on-surface">{length(@referrals)}</p>
        </div>
        <div class="bg-surface-container p-6 rounded-2xl">
          <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2">
            Completed
          </p>
          <p class="text-3xl font-mono font-medium text-secondary">
            {Enum.count(@referrals, &(&1.status == :completed))}
          </p>
        </div>
        <div class="bg-surface-container p-6 rounded-2xl">
          <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2">
            Total Earned
          </p>
          <p class="text-3xl font-mono font-medium text-primary">
            {"$#{format_cents(@total_earned)}"}
          </p>
        </div>
      </div>

      <%!-- Referrals Table --%>
      <div class="bg-surface-container rounded-2xl p-6">
        <h2 class="text-lg font-bold text-on-surface mb-4">Referral History</h2>
        <%= if @referrals == [] do %>
          <p class="text-on-surface-variant text-sm">
            No referrals yet. Share your code to get started!
          </p>
        <% else %>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-outline-variant text-left">
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">
                    Code
                  </th>
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">
                    Status
                  </th>
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">
                    Reward
                  </th>
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">
                    Date
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={referral <- @referrals}
                  class="border-b border-outline-variant/50 hover:bg-surface-container-high transition-colors"
                >
                  <td class="py-3 px-4 font-mono text-on-surface">{referral.code}</td>
                  <td class="py-3 px-4">
                    <span class={[
                      "inline-flex px-2 py-0.5 rounded-full text-xs font-semibold",
                      status_color(referral.status)
                    ]}>
                      {referral.status |> to_string() |> String.capitalize()}
                    </span>
                  </td>
                  <td class="py-3 px-4 font-mono text-on-surface">
                    {"$#{format_cents(referral.reward_amount_cents)}"}
                  </td>
                  <td class="py-3 px-4 text-on-surface-variant">
                    {Calendar.strftime(referral.inserted_at, "%b %d, %Y")}
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

  defp load_referrals(nil), do: []

  defp load_referrals(user) do
    FounderPad.Referrals.Referral
    |> Ash.Query.filter(referrer_id == ^user.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!()
  end

  defp get_or_create_referral_code(nil), do: nil

  defp get_or_create_referral_code(user) do
    case FounderPad.Referrals.Referral
         |> Ash.Query.filter(referrer_id == ^user.id and status == :pending)
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(1)
         |> Ash.read!() do
      [referral | _] -> referral.code
      [] -> nil
    end
  end

  defp calculate_total_earned(referrals) do
    referrals
    |> Enum.filter(&(&1.status == :completed))
    |> Enum.reduce(0, &(&1.reward_amount_cents + &2))
  end

  defp format_cents(cents) do
    dollars = div(cents, 100)
    remainder = rem(cents, 100)
    "#{dollars}.#{String.pad_leading("#{remainder}", 2, "0")}"
  end

  defp status_color(:completed), do: "bg-secondary/10 text-secondary"
  defp status_color(:pending), do: "bg-warning/10 text-warning"
  defp status_color(:expired), do: "bg-error/10 text-error"
  defp status_color(_), do: "bg-surface-container-high text-on-surface-variant"
end
