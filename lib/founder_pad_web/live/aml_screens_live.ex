defmodule FounderPadWeb.AmlScreensLive do
  @moduledoc "Compliance view: AML screening results for the tenant."
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    org = current_org(socket.assigns.current_user)

    {:ok,
     assign(socket,
       page_title: "AML Screening",
       active_nav: :aml_screens,
       org: org,
       screens: load(org)
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-5xl mx-auto">
      <header>
        <div class="flex items-center gap-2 text-xs font-mono text-on-surface-variant/60 uppercase tracking-widest mb-2">
          <span class="material-symbols-outlined text-sm text-primary">policy</span> Compliance
        </div>
        <h1 class="text-4xl font-extrabold font-headline tracking-tight">AML Screening</h1>
        <p class="text-on-surface-variant mt-1">
          Sanctions, PEP and adverse-media screens. Matches require human review —
          no automated final AML decision.
        </p>
      </header>

      <div :if={@screens == []} class="text-center py-16">
        <span class="material-symbols-outlined text-6xl text-on-surface-variant/30 mb-4 block">
          policy
        </span>
        <h3 class="text-xl font-bold font-headline mb-2">No AML screens yet</h3>
        <p class="text-on-surface-variant">
          Pass <code class="font-mono">options.run_aml_screen</code> on a verification.
        </p>
      </div>

      <table :if={@screens != []} class="w-full text-sm">
        <thead class="text-left text-xs uppercase text-on-surface-variant border-b border-outline-variant/20">
          <tr>
            <th class="py-2">Subject</th>
            <th class="py-2">Status</th>
            <th class="py-2">Lists</th>
            <th class="py-2">Matches</th>
            <th class="py-2">Confidence</th>
            <th class="py-2">When</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={s <- @screens} class="border-b border-outline-variant/10">
            <td class="py-3">{s.subject_type}</td>
            <td class="py-3">
              <span class={["px-2 py-0.5 rounded text-xs font-bold", status_badge(s.status)]}>
                {s.status}
              </span>
            </td>
            <td class="py-3 font-mono text-xs">{Enum.join(s.lists_checked, ", ")}</td>
            <td class="py-3">{s.match_count}</td>
            <td class="py-3">{to_string(s.highest_confidence)}</td>
            <td class="py-3 font-mono text-xs text-on-surface-variant">
              {Calendar.strftime(s.inserted_at, "%Y-%m-%d %H:%M")}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp load(nil), do: []
  defp load(org), do: FounderPad.Compliance.list_aml_screens_by_organisation!(org.id)

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

  defp status_badge(:clear), do: "bg-primary/10 text-primary"
  defp status_badge(:possible_match), do: "bg-secondary/10 text-secondary"
  defp status_badge(:confirmed_match), do: "bg-error/10 text-error"
  defp status_badge(_), do: "bg-on-surface-variant/10 text-on-surface-variant"
end
