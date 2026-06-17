defmodule FounderPadWeb.VerificationsLive do
  @moduledoc "Compliance view: list of individual identity verifications for the tenant."
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    org = current_org(socket.assigns.current_user)
    verifications = load_verifications(org)

    {:ok,
     assign(socket,
       page_title: "Verifications",
       active_nav: :verifications,
       org: org,
       verifications: verifications,
       summary: summarise(verifications)
     )}
  end

  # Verification volume by status — the compliance "usage" view (distinct from
  # billing usage).
  defp summarise(verifications) do
    counts = Enum.frequencies_by(verifications, & &1.status)

    %{
      total: length(verifications),
      verified: Map.get(counts, :verified, 0),
      requires_review: Map.get(counts, :requires_review, 0),
      failed: Map.get(counts, :failed, 0)
    }
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <header>
        <div class="flex items-center gap-2 text-xs font-mono text-on-surface-variant/60 uppercase tracking-widest mb-2">
          <span class="material-symbols-outlined text-sm text-primary">verified_user</span> Compliance
        </div>
        <h1 class="text-4xl font-extrabold font-headline tracking-tight">Verifications</h1>
        <p class="text-on-surface-variant mt-1">
          Individual identity checks against the Ghana Card, with risk and consent.
        </p>
      </header>

      <dl class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <.stat label="Total" value={@summary.total} />
        <.stat label="Verified" value={@summary.verified} tone="text-primary" />
        <.stat label="Needs review" value={@summary.requires_review} tone="text-secondary" />
        <.stat label="Failed" value={@summary.failed} tone="text-error" />
      </dl>

      <div :if={@verifications == []} class="text-center py-16">
        <span class="material-symbols-outlined text-6xl text-on-surface-variant/30 mb-4 block">
          fingerprint
        </span>
        <h3 class="text-xl font-bold font-headline mb-2">No verifications yet</h3>
        <p class="text-on-surface-variant">
          Create one via <code class="font-mono">POST /v1/individual_verifications</code>.
        </p>
      </div>

      <table :if={@verifications != []} class="w-full text-sm">
        <thead class="text-left text-xs uppercase text-on-surface-variant border-b border-outline-variant/20">
          <tr>
            <th class="py-2">External ID</th>
            <th class="py-2">Status</th>
            <th class="py-2">Mode</th>
            <th class="py-2">Risk</th>
            <th class="py-2">Created</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={v <- @verifications} class="border-b border-outline-variant/10">
            <td class="py-3 font-mono">{v.external_id || "—"}</td>
            <td class="py-3">
              <span class={["px-2 py-0.5 rounded text-xs font-bold", status_badge(v.status)]}>
                {v.status}
              </span>
            </td>
            <td class="py-3">{v.mode}</td>
            <td class="py-3">{v.risk_level || "—"}</td>
            <td class="py-3 font-mono text-xs text-on-surface-variant">
              {Calendar.strftime(v.inserted_at, "%Y-%m-%d %H:%M")}
            </td>
            <td class="py-3 text-right">
              <.link navigate={~p"/verifications/#{v.id}"} class="text-primary hover:underline">
                View
              </.link>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :tone, :string, default: "text-on-surface"

  defp stat(assigns) do
    ~H"""
    <div class="bg-surface-container rounded-lg p-4">
      <dt class="text-xs uppercase text-on-surface-variant">{@label}</dt>
      <dd class={["text-2xl font-extrabold mt-1", @tone]}>{@value}</dd>
    </div>
    """
  end

  defp load_verifications(nil), do: []

  defp load_verifications(org) do
    FounderPad.Compliance.list_individual_verifications_by_organisation!(org.id)
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

  defp status_badge(:verified), do: "bg-primary/10 text-primary"
  defp status_badge(:failed), do: "bg-error/10 text-error"
  defp status_badge(:requires_review), do: "bg-secondary/10 text-secondary"
  defp status_badge(_), do: "bg-on-surface-variant/10 text-on-surface-variant"
end
