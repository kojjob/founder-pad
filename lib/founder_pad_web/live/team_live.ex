defmodule FounderPadWeb.TeamLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_nav: :team,
       page_title: "Team",
       members: sample_members(),
       stats: %{total: 24, active: 8, pending: 3, api_pct: 82}
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-16">
      <%!-- Hero Header (Editorial style from Stitch) --%>
      <div class="flex justify-between items-end">
        <div class="max-w-2xl">
          <nav class="flex items-center gap-2 mb-4 text-xs font-label text-on-surface-variant/60">
            <span>Settings</span>
            <span class="material-symbols-outlined text-[12px]">chevron_right</span>
            <span class="text-primary font-medium">Team Management</span>
          </nav>
          <h2 class="font-headline text-5xl font-extrabold text-on-surface tracking-tight mb-4">
            Your Collective.
          </h2>
          <p class="text-on-surface-variant text-lg leading-relaxed">
            Orchestrate access levels and monitor team velocity across your multi-tenant environments.
          </p>
        </div>
        <button class="primary-gradient text-on-primary px-6 py-3 rounded-lg flex items-center gap-2 font-label font-semibold text-sm tracking-wider uppercase editorial-shadow hover:scale-[1.02] transition-transform">
          <span class="material-symbols-outlined text-sm">person_add</span>
          Invite New Member
        </button>
      </div>

      <%!-- Stats Grid --%>
      <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
        <.stat_card label="Total Members" value={@stats.total} color="primary" />
        <.stat_card label="Active Now" value={String.pad_leading("#{@stats.active}", 2, "0")} color="secondary" />
        <.stat_card label="Pending Invitations" value={String.pad_leading("#{@stats.pending}", 2, "0")} color="on-surface-variant" />
        <.stat_card label="API Consumption" value="#{@stats.api_pct}%" color="on-surface" />
      </div>

      <%!-- Team Members Table --%>
      <div class="bg-surface-container-lowest rounded-2xl overflow-hidden editorial-shadow">
        <div class="px-8 py-6 flex items-center justify-between bg-surface-container-low/30">
          <h3 class="font-headline text-xl font-bold">Active Members</h3>
          <div class="flex gap-4">
            <button class="flex items-center gap-2 text-xs font-semibold text-on-surface-variant/60 hover:text-primary transition-colors">
              <span class="material-symbols-outlined text-sm">filter_list</span>
              Filter
            </button>
            <button class="flex items-center gap-2 text-xs font-semibold text-on-surface-variant/60 hover:text-primary transition-colors">
              <span class="material-symbols-outlined text-sm">download</span>
              Export
            </button>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-left">
            <thead>
              <tr class="bg-surface-container-low/50">
                <th class="px-8 py-4 font-label text-[10px] font-bold uppercase tracking-[0.15em] text-on-surface-variant/50">Name</th>
                <th class="px-8 py-4 font-label text-[10px] font-bold uppercase tracking-[0.15em] text-on-surface-variant/50">Role</th>
                <th class="px-8 py-4 font-label text-[10px] font-bold uppercase tracking-[0.15em] text-on-surface-variant/50">Status</th>
                <th class="px-8 py-4 font-label text-[10px] font-bold uppercase tracking-[0.15em] text-on-surface-variant/50">Last Active</th>
                <th class="px-8 py-4 font-label text-[10px] font-bold uppercase tracking-[0.15em] text-on-surface-variant/50 text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={m <- @members} class="hover:bg-surface-container-low/30 transition-colors group">
                <td class="px-8 py-6">
                  <div class="flex items-center gap-4">
                    <div class={[
                      "w-10 h-10 rounded-full flex items-center justify-center font-headline font-bold text-sm",
                      role_avatar_class(m.role)
                    ]}>
                      {initials(m.name)}
                    </div>
                    <div>
                      <p class="font-body font-semibold text-sm text-on-surface">{m.name}</p>
                      <p class="font-body text-xs text-on-surface-variant/50">{m.email}</p>
                    </div>
                  </div>
                </td>
                <td class="px-8 py-6">
                  <span class={["px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider", role_badge_class(m.role)]}>
                    {role_label(m.role)}
                  </span>
                </td>
                <td class="px-8 py-6">
                  <div class="flex items-center gap-2">
                    <div class={["w-2 h-2 rounded-full", status_dot_class(m.status)]}></div>
                    <span class="font-body text-xs text-on-surface-variant">{status_label(m.status)}</span>
                  </div>
                </td>
                <td class="px-8 py-6">
                  <span class="font-mono text-xs text-on-surface-variant/50">{m.last_active}</span>
                </td>
                <td class="px-8 py-6 text-right">
                  <button class="p-2 opacity-0 group-hover:opacity-100 text-on-surface-variant/40 hover:text-primary transition-all">
                    <span class="material-symbols-outlined">more_vert</span>
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <%!-- Pagination --%>
        <div class="px-8 py-4 flex items-center justify-between text-xs text-on-surface-variant/50">
          <span>Showing 1-4 of 24 members</span>
          <div class="flex gap-1">
            <button :for={p <- 1..4} class={[
              "w-8 h-8 rounded-lg flex items-center justify-center text-xs font-medium transition-colors",
              if(p == 1, do: "bg-primary text-on-primary", else: "hover:bg-surface-container-high text-on-surface-variant")
            ]}>
              {p}
            </button>
          </div>
        </div>
      </div>

      <%!-- Security CTA Section --%>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div class="space-y-4">
          <h3 class="font-headline text-2xl font-bold text-on-surface">Integrate Security Protocols</h3>
          <p class="text-on-surface-variant leading-relaxed">
            Reinforce your team's perimeter with SSO, RBAC, and multi-factor authentication requirements.
            Ensure your institutional knowledge remains secure.
          </p>
          <button class="flex items-center gap-2 text-primary font-semibold text-sm hover:gap-3 transition-all">
            Configure Security Settings
            <span class="material-symbols-outlined text-sm">arrow_forward</span>
          </button>
        </div>
        <div class="bg-surface-container-lowest rounded-2xl p-8 flex items-center justify-center editorial-shadow">
          <div class="flex items-center gap-6 text-on-surface-variant/30">
            <span class="material-symbols-outlined text-5xl">lock</span>
            <span class="material-symbols-outlined text-5xl">admin_panel_settings</span>
            <span class="material-symbols-outlined text-5xl">verified_user</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-surface-container-lowest p-6 rounded-xl editorial-shadow">
      <p class="font-label text-xs font-semibold text-on-surface-variant/50 uppercase tracking-widest mb-1">{@label}</p>
      <p class={"font-mono text-3xl font-medium text-#{@color}"}>{@value}</p>
    </div>
    """
  end

  defp initials(name) do
    name
    |> String.split(" ")
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
  end

  defp role_avatar_class(:owner), do: "bg-primary-fixed text-primary"
  defp role_avatar_class(:admin), do: "bg-primary-fixed text-primary"
  defp role_avatar_class(_), do: "bg-surface-container-high text-on-surface-variant"

  defp role_badge_class(:owner), do: "bg-primary-fixed text-on-primary-fixed-variant"
  defp role_badge_class(:admin), do: "bg-secondary-fixed text-on-secondary-fixed-variant"
  defp role_badge_class(:member), do: "bg-surface-container-high text-on-surface-variant"

  defp role_label(:owner), do: "Administrator"
  defp role_label(:admin), do: "Model Architect"
  defp role_label(:member), do: "Contributor"

  defp status_dot_class(:online), do: "bg-emerald-500"
  defp status_dot_class(:away), do: "bg-outline-variant"
  defp status_dot_class(:offline), do: "bg-outline-variant"

  defp status_label(:online), do: "Online"
  defp status_label(:away), do: "Away"
  defp status_label(:offline), do: "Offline"

  defp sample_members do
    [
      %{name: "Sarah Chen", email: "sarah.c@company.com", role: :owner, status: :online, last_active: "2026-03-19 14:22"},
      %{name: "Marcus Thorne", email: "m.thorne@company.com", role: :admin, status: :online, last_active: "2026-03-19 09:15"},
      %{name: "Elena Vance", email: "elena@company.com", role: :member, status: :away, last_active: "2026-03-18 18:44"},
      %{name: "Julian Rossi", email: "j.rossi@company.com", role: :member, status: :offline, last_active: "2026-03-18 14:30"}
    ]
  end
end
