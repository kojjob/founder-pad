defmodule FounderPadWeb.TeamLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_nav: :team, page_title: "Team", members: sample_members())}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <section class="flex items-end justify-between">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">Team Management</h1>
          <p class="text-on-surface-variant mt-1">
            {length(@members)} members &bull; 20 seats available
          </p>
        </div>
        <button class="bg-gradient-to-br from-primary to-primary-container text-on-primary-fixed font-semibold px-4 py-2 rounded-lg text-sm">
          <span class="flex items-center gap-2">
            <span class="material-symbols-outlined text-lg">person_add</span> Invite Member
          </span>
        </button>
      </section>

      <div class="bg-surface-container rounded-lg overflow-hidden">
        <div class="grid grid-cols-12 gap-4 px-6 py-3 text-xs font-mono uppercase tracking-widest text-on-surface-variant border-b border-outline-variant/10">
          <div class="col-span-4">Member</div>
          <div class="col-span-3">Role</div>
          <div class="col-span-3">Joined</div>
          <div class="col-span-2">Actions</div>
        </div>
        <div
          :for={m <- @members}
          class="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-surface-container-high/50 transition-colors"
        >
          <div class="col-span-4 flex items-center gap-3">
            <div class="w-8 h-8 rounded-full bg-primary-container flex items-center justify-center text-xs font-bold text-on-primary-fixed">
              {String.first(m.name)}
            </div>
            <div>
              <p class="text-sm font-semibold">{m.name}</p>
              <p class="text-xs text-on-surface-variant">{m.email}</p>
            </div>
          </div>
          <div class="col-span-3">
            <span class={[
              "px-2 py-0.5 rounded-full text-[10px] font-bold",
              role_badge_class(m.role)
            ]}>
              {m.role |> to_string() |> String.capitalize()}
            </span>
          </div>
          <div class="col-span-3 text-sm text-on-surface-variant font-mono">{m.joined}</div>
          <div class="col-span-2">
            <button class="material-symbols-outlined text-on-surface-variant hover:text-on-surface transition-colors text-lg">
              more_vert
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp role_badge_class(:owner), do: "bg-primary/10 text-primary"
  defp role_badge_class(:admin), do: "bg-secondary/10 text-secondary"
  defp role_badge_class(_), do: "bg-on-surface-variant/10 text-on-surface-variant"

  defp sample_members do
    [
      %{name: "Sarah Chen", email: "sarah@company.com", role: :owner, joined: "Jan 2026"},
      %{name: "Alex Rivera", email: "alex@company.com", role: :admin, joined: "Jan 2026"},
      %{name: "Jordan Park", email: "jordan@company.com", role: :member, joined: "Feb 2026"},
      %{name: "Casey Morgan", email: "casey@company.com", role: :member, joined: "Mar 2026"}
    ]
  end
end
