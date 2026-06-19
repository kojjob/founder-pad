defmodule FounderPadWeb.ConsentReceiptsLive do
  @moduledoc "Compliance view: the tenant's consent receipts, with withdrawal."
  use FounderPadWeb, :live_view

  require Ash.Query

  alias FounderPad.Compliance.ConsentReceipt

  def mount(_params, _session, socket) do
    org = current_org(socket.assigns.current_user)

    {:ok,
     assign(socket,
       page_title: "Consent Receipts",
       active_nav: :consent,
       org: org,
       receipts: load_receipts(org)
     )}
  end

  def handle_event("withdraw", %{"id" => id}, socket) do
    with {:ok, receipt} <- fetch_receipt(id, socket.assigns.org),
         {:ok, _} <- receipt |> Ash.Changeset.for_update(:withdraw, %{}) |> Ash.update() do
      {:noreply,
       socket
       |> put_flash(:info, "Consent withdrawn.")
       |> assign(receipts: load_receipts(socket.assigns.org))}
    else
      _ -> {:noreply, put_flash(socket, :error, "Could not withdraw consent.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-5xl mx-auto">
      <header>
        <div class="flex items-center gap-2 text-xs font-mono text-on-surface-variant/60 uppercase tracking-widest mb-2">
          <span class="material-symbols-outlined text-sm text-primary">fact_check</span> Compliance
        </div>
        <h1 class="text-4xl font-extrabold font-headline tracking-tight">Consent Receipts</h1>
        <p class="text-on-surface-variant mt-1">
          Evidence of consent to process personal data, per data subject and purpose.
        </p>
      </header>

      <div :if={@receipts == []} class="text-center py-16">
        <span class="material-symbols-outlined text-6xl text-on-surface-variant/30 mb-4 block">
          fact_check
        </span>
        <h3 class="text-xl font-bold font-headline mb-2">No consent receipts yet</h3>
        <p class="text-on-surface-variant">
          Receipts are recorded when a live verification captures consent.
        </p>
      </div>

      <table :if={@receipts != []} class="w-full text-sm">
        <thead class="text-left text-xs uppercase text-on-surface-variant border-b border-outline-variant/20">
          <tr>
            <th class="py-2">Subject</th>
            <th class="py-2">Purpose</th>
            <th class="py-2">Channel</th>
            <th class="py-2">Status</th>
            <th class="py-2">Accepted</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={r <- @receipts} class="border-b border-outline-variant/10">
            <td class="py-3 font-mono">{r.external_subject_id || "—"}</td>
            <td class="py-3">{r.purpose}</td>
            <td class="py-3">{r.channel}</td>
            <td class="py-3">
              <span class={["px-2 py-0.5 rounded text-xs font-bold", status_badge(r.status)]}>
                {r.status}
              </span>
            </td>
            <td class="py-3 font-mono text-xs text-on-surface-variant">
              {r.accepted_at && Calendar.strftime(r.accepted_at, "%Y-%m-%d")}
            </td>
            <td class="py-3 text-right">
              <button
                :if={r.status == :active}
                phx-click="withdraw"
                phx-value-id={r.id}
                class="text-error hover:underline text-xs"
              >
                Withdraw
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp load_receipts(nil), do: []

  defp load_receipts(org),
    do: FounderPad.Compliance.list_consent_receipts_by_organisation!(org.id)

  defp fetch_receipt(id, org) do
    case Ash.get(ConsentReceipt, id, authorize?: false) do
      {:ok, %{organisation_id: org_id} = r} when org_id == org.id -> {:ok, r}
      _ -> :error
    end
  end

  defp current_org(user) do
    FounderPad.Accounts.Membership
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.load([:organisation])
    |> Ash.read!()
    |> case do
      [m | _] -> m.organisation
      [] -> nil
    end
  end

  defp status_badge(:active), do: "bg-primary/10 text-primary"
  defp status_badge(:withdrawn), do: "bg-error/10 text-error"
  defp status_badge(_), do: "bg-on-surface-variant/10 text-on-surface-variant"
end
