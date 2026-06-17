defmodule FounderPadWeb.BusinessVerificationsLive do
  @moduledoc "Compliance view: list of business (KYB) verifications for the tenant."
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    org = current_org(socket.assigns.current_user)

    {:ok,
     assign(socket,
       page_title: "Business Verifications",
       active_nav: :business_verifications,
       org: org,
       verifications: load(org)
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <header>
        <div class="flex items-center gap-2 text-xs font-mono text-on-surface-variant/60 uppercase tracking-widest mb-2">
          <span class="material-symbols-outlined text-sm text-primary">store</span> Compliance
        </div>
        <h1 class="text-4xl font-extrabold font-headline tracking-tight">Business Verifications</h1>
        <p class="text-on-surface-variant mt-1">
          KYB checks against business registration and TIN, with risk and review.
        </p>
      </header>

      <div :if={@verifications == []} class="text-center py-16">
        <span class="material-symbols-outlined text-6xl text-on-surface-variant/30 mb-4 block">
          store
        </span>
        <h3 class="text-xl font-bold font-headline mb-2">No business verifications yet</h3>
        <p class="text-on-surface-variant">
          Create one via <code class="font-mono">POST /v1/business_verifications</code>.
        </p>
      </div>

      <table :if={@verifications != []} class="w-full text-sm">
        <thead class="text-left text-xs uppercase text-on-surface-variant border-b border-outline-variant/20">
          <tr>
            <th class="py-2">Business</th>
            <th class="py-2">External ID</th>
            <th class="py-2">Status</th>
            <th class="py-2">Risk</th>
            <th class="py-2">Created</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={v <- @verifications} class="border-b border-outline-variant/10">
            <td class="py-3">{v.registered_name || "—"}</td>
            <td class="py-3 font-mono">{v.external_id || "—"}</td>
            <td class="py-3">
              <span class={["px-2 py-0.5 rounded text-xs font-bold", status_badge(v.status)]}>
                {v.status}
              </span>
            </td>
            <td class="py-3">{v.risk_level || "—"}</td>
            <td class="py-3 font-mono text-xs text-on-surface-variant">
              {Calendar.strftime(v.inserted_at, "%Y-%m-%d %H:%M")}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp load(nil), do: []
  defp load(org), do: FounderPad.Compliance.list_business_verifications_by_organisation!(org.id)

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

  defp status_badge(:verified), do: "bg-primary/10 text-primary"
  defp status_badge(:failed), do: "bg-error/10 text-error"
  defp status_badge(:requires_review), do: "bg-secondary/10 text-secondary"
  defp status_badge(_), do: "bg-on-surface-variant/10 text-on-surface-variant"
end
