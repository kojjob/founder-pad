defmodule FounderPadWeb.TeamLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_nav: :team,
       page_title: "Team",
       search_query: "",
       current_page: 1,
       members: sample_members(),
       total_seats: 30,
       used_seats: 24,
       active_now: 12,
       pending: 3,
       next_billing: "Oct 24"
     )}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply, assign(socket, current_page: String.to_integer(page))}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Header Area --%>
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-end gap-6">
        <div class="max-w-2xl">
          <nav class="flex items-center gap-1.5 mb-4 text-xs font-mono text-on-surface-variant/50 uppercase tracking-widest">
            <span>Organization</span>
            <span class="text-on-surface-variant/30">›</span>
            <span class="text-primary">Team_Management</span>
          </nav>
          <h1 class="font-headline text-4xl sm:text-5xl font-extrabold text-on-surface tracking-tight mb-3">
            Organization Members
          </h1>
          <p class="text-on-surface-variant text-sm leading-relaxed max-w-lg">
            Manage permissions, invite technical collaborators, and audit administrative access for
            the Agent Architecture cluster.
          </p>
        </div>
        <button class="primary-gradient text-on-primary px-6 py-3 rounded-lg flex items-center gap-2 font-label font-semibold text-xs tracking-wider uppercase editorial-shadow hover:scale-[1.02] transition-transform whitespace-nowrap">
          <span class="material-symbols-outlined text-sm">person_add</span>
          Invite New Member
        </button>
      </div>

      <%!-- Stats Row --%>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <%!-- Total Seats --%>
        <div class="bg-surface-container rounded-xl p-5">
          <p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50 mb-2">
            Total Seats
          </p>
          <div class="flex items-baseline gap-1">
            <span class="font-mono text-2xl font-bold text-on-surface">{@used_seats}</span>
            <span class="font-mono text-sm text-on-surface-variant/40">/ {@total_seats}</span>
          </div>
          <div class="mt-3 h-1 bg-surface-container-highest rounded-full overflow-hidden">
            <div
              class="h-full bg-primary rounded-full transition-all"
              style={"width: #{round(@used_seats / @total_seats * 100)}%"}
            >
            </div>
          </div>
        </div>

        <%!-- Active Now --%>
        <div class="bg-surface-container rounded-xl p-5">
          <p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50 mb-2">
            Active Now
          </p>
          <div class="flex items-center gap-3">
            <span class="font-mono text-2xl font-bold text-on-surface">{@active_now}</span>
            <span class="flex items-center gap-1.5">
              <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              <span class="text-[10px] font-semibold uppercase tracking-wider text-emerald-500">Live</span>
            </span>
          </div>
        </div>

        <%!-- Pending --%>
        <div class="bg-surface-container rounded-xl p-5">
          <p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50 mb-2">
            Pending
          </p>
          <span class="font-mono text-2xl font-bold text-on-surface">
            {String.pad_leading("#{@pending}", 2, "0")}
          </span>
        </div>

        <%!-- Next Billing --%>
        <div class="bg-surface-container rounded-xl p-5">
          <p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50 mb-2">
            Next Billing
          </p>
          <span class="font-mono text-2xl font-bold text-on-surface">{@next_billing}</span>
        </div>
      </div>

      <%!-- Search Bar --%>
      <div class="relative">
        <span class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-on-surface-variant/40 text-xl">
          search
        </span>
        <input
          type="text"
          placeholder="Search by name, email, or role..."
          value={@search_query}
          phx-keyup="search"
          phx-key="Enter"
          class="w-full pl-12 pr-4 py-3.5 bg-surface-container rounded-xl border border-outline-variant/20 text-sm text-on-surface placeholder-on-surface-variant/40 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary/50 transition-all"
        />
        <div class="absolute right-4 top-1/2 -translate-y-1/2 flex items-center gap-3">
          <button class="flex items-center gap-1.5 text-xs font-semibold text-on-surface-variant/50 hover:text-primary transition-colors">
            <span class="material-symbols-outlined text-sm">filter_list</span>
            Filter
          </button>
          <button class="flex items-center gap-1.5 text-xs font-semibold text-on-surface-variant/50 hover:text-primary transition-colors">
            <span class="material-symbols-outlined text-sm">download</span>
            Export
          </button>
        </div>
      </div>

      <%!-- Members Table --%>
      <div class="bg-surface-container rounded-xl overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-left">
            <thead>
              <tr class="border-b border-outline-variant/10">
                <th class="px-6 py-4 font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50">
                  Member Name
                </th>
                <th class="px-6 py-4 font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50">
                  Role
                </th>
                <th class="px-6 py-4 font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50">
                  Status
                </th>
                <th class="px-6 py-4 font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50">
                  Last Active
                </th>
                <th class="px-6 py-4 font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50 text-right">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={m <- filtered_members(@members, @search_query)}
                class="border-b border-outline-variant/5 hover:bg-surface-container-high/30 transition-colors group"
              >
                <%!-- Member Name + Avatar --%>
                <td class="px-6 py-4">
                  <div class="flex items-center gap-3">
                    <%= if m.avatar do %>
                      <img
                        src={m.avatar}
                        alt={m.name}
                        class="w-10 h-10 rounded-full object-cover ring-2 ring-surface-container-highest/50"
                      />
                    <% else %>
                      <div class={[
                        "w-10 h-10 rounded-full flex items-center justify-center font-headline font-bold text-sm",
                        avatar_bg_class(m.role)
                      ]}>
                        {initials(m.name)}
                      </div>
                    <% end %>
                    <div>
                      <p class="font-body font-semibold text-sm text-on-surface">{m.name}</p>
                      <p class="font-body text-xs text-on-surface-variant/50">{m.email}</p>
                    </div>
                  </div>
                </td>

                <%!-- Role Badge --%>
                <td class="px-6 py-4">
                  <span class={[
                    "inline-flex px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider",
                    role_badge_class(m.role)
                  ]}>
                    {role_label(m.role)}
                  </span>
                </td>

                <%!-- Status --%>
                <td class="px-6 py-4">
                  <div class="flex items-center gap-2">
                    <span class={["w-2 h-2 rounded-full", status_dot_class(m.status)]}></span>
                    <span class="font-body text-xs text-on-surface-variant">{status_label(m.status)}</span>
                  </div>
                </td>

                <%!-- Last Active --%>
                <td class="px-6 py-4">
                  <span class="font-mono text-xs text-on-surface-variant/50">{m.last_active}</span>
                </td>

                <%!-- Actions --%>
                <td class="px-6 py-4 text-right">
                  <%= if m.role == :owner do %>
                    <button class="px-3 py-1.5 rounded-lg bg-surface-container-highest/50 text-[10px] font-bold uppercase tracking-wider text-on-surface-variant hover:bg-surface-container-highest transition-colors">
                      Manage Seats
                    </button>
                  <% else %>
                    <div class="flex items-center justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button class="p-1.5 rounded-lg text-on-surface-variant/40 hover:text-primary hover:bg-primary/5 transition-all">
                        <span class="material-symbols-outlined text-lg">edit</span>
                      </button>
                      <button class="p-1.5 rounded-lg text-on-surface-variant/40 hover:text-error hover:bg-error/5 transition-all">
                        <span class="material-symbols-outlined text-lg">delete</span>
                      </button>
                      <button class="p-1.5 rounded-lg text-on-surface-variant/40 hover:text-on-surface hover:bg-surface-container-highest/50 transition-all">
                        <span class="material-symbols-outlined text-lg">more_vert</span>
                      </button>
                    </div>
                  <% end %>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Pagination --%>
        <div class="px-6 py-4 flex items-center justify-between border-t border-outline-variant/10">
          <span class="text-xs text-on-surface-variant/50">
            Showing {(@current_page - 1) * 4 + 1}-{min(@current_page * 4, length(@members))} of {length(@members)} members
          </span>
          <div class="flex items-center gap-1">
            <button class="w-8 h-8 rounded-lg flex items-center justify-center text-on-surface-variant/40 hover:bg-surface-container-high transition-colors">
              <span class="material-symbols-outlined text-sm">chevron_left</span>
            </button>
            <button
              :for={p <- 1..max(1, ceil(length(@members) / 4))}
              phx-click="change_page"
              phx-value-page={p}
              class={[
                "w-8 h-8 rounded-lg flex items-center justify-center text-xs font-medium transition-colors",
                if(p == @current_page,
                  do: "bg-primary text-on-primary",
                  else: "text-on-surface-variant hover:bg-surface-container-high"
                )
              ]}
            >
              {p}
            </button>
            <button class="w-8 h-8 rounded-lg flex items-center justify-center text-on-surface-variant/40 hover:bg-surface-container-high transition-colors">
              <span class="material-symbols-outlined text-sm">chevron_right</span>
            </button>
          </div>
        </div>
      </div>

      <%!-- Audit Logs Info Bar --%>
      <div class="bg-surface-container rounded-xl px-6 py-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div class="flex items-start gap-3">
          <span class="material-symbols-outlined text-primary text-xl mt-0.5">verified</span>
          <div>
            <p class="font-headline font-bold text-sm text-on-surface">Audit Logs Ready</p>
            <p class="text-xs text-on-surface-variant/60 leading-relaxed mt-0.5">
              Member activity and permission shifts are being logged for your compliance experts.
            </p>
          </div>
        </div>
        <button class="flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-primary hover:text-primary/80 transition-colors whitespace-nowrap">
          View Audit Trail
          <span class="material-symbols-outlined text-sm">arrow_forward</span>
        </button>
      </div>
    </div>
    """
  end

  # ── Helpers ──

  defp initials(name) do
    name
    |> String.split(" ")
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
  end

  defp filtered_members(members, ""), do: members

  defp filtered_members(members, query) do
    q = String.downcase(query)

    Enum.filter(members, fn m ->
      String.contains?(String.downcase(m.name), q) or
        String.contains?(String.downcase(m.email), q) or
        String.contains?(String.downcase(Atom.to_string(m.role)), q)
    end)
  end

  defp avatar_bg_class(:owner), do: "bg-primary/10 text-primary"
  defp avatar_bg_class(:developer), do: "bg-secondary/10 text-secondary"
  defp avatar_bg_class(_), do: "bg-surface-container-highest text-on-surface-variant"

  defp role_badge_class(:owner), do: "bg-primary/10 text-primary"
  defp role_badge_class(:developer), do: "bg-secondary/10 text-secondary"
  defp role_badge_class(:contributor), do: "bg-surface-container-highest text-on-surface-variant"
  defp role_badge_class(_), do: "bg-surface-container-highest text-on-surface-variant"

  defp role_label(:owner), do: "Owner"
  defp role_label(:developer), do: "Developer"
  defp role_label(:contributor), do: "Contributor"
  defp role_label(_), do: "Member"

  defp status_dot_class(:active), do: "bg-emerald-500"
  defp status_dot_class(:offline), do: "bg-outline-variant/60"
  defp status_dot_class(_), do: "bg-outline-variant/60"

  defp status_label(:active), do: "Active"
  defp status_label(:offline), do: "Offline"
  defp status_label(_), do: "Offline"

  defp sample_members do
    [
      %{
        name: "Adrian Stern",
        email: "a.stern@agent-os.dev",
        role: :owner,
        status: :active,
        last_active: "2025-10-24 16:22:05",
        avatar: nil
      },
      %{
        name: "Elena Rodriguez",
        email: "elena.r@company.com",
        role: :developer,
        status: :active,
        last_active: "2025-10-24 09:15:23",
        avatar: nil
      },
      %{
        name: "Marcus Holloway",
        email: "m.holloway@org.io",
        role: :contributor,
        status: :active,
        last_active: "2025-10-23 18:44:00",
        avatar: nil
      },
      %{
        name: "Sarah Chen",
        email: "sarah@company.com",
        role: :developer,
        status: :offline,
        last_active: "2025-10-22 22:10:45",
        avatar: nil
      }
    ]
  end
end
