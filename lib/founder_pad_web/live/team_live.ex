defmodule FounderPadWeb.TeamLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  @per_page 6

  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]
    org_id = get_user_org_id(user)
    plan = load_plan(org_id)
    members = reload_members(org_id)

    {:ok,
     assign(socket,
       active_nav: :team,
       page_title: "Team",
       search_query: "",
       current_page: 1,
       members: members,
       total_seats: if(plan, do: plan.max_seats, else: 5),
       used_seats: length(members),
       active_now: Enum.count(members, fn m -> m.status == :active end),
       pending: 0,
       next_billing: next_billing_date(),
       show_invite_modal: false,
       show_seats_modal: false,
       new_seat_count: if(plan, do: plan.max_seats, else: 5),
       invite_emails: [],
       invite_email_input: "",
       invite_role: "member",
       invite_error: nil,
       invite_success_count: 0,
       role_edit_id: nil,
       org_id: org_id,
       current_user_role: get_current_user_role(user, org_id)
     )}
  end

  # ── Event Handlers ──

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query, current_page: 1)}
  end

  def handle_event("live_search", %{"value" => query}, socket) do
    {:noreply, assign(socket, search_query: query, current_page: 1)}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page_num =
      case Integer.parse(page) do
        {n, _} when n > 0 -> n
        _ -> 1
      end

    {:noreply, assign(socket, current_page: page_num)}
  end

  def handle_event("prev_page", _, socket) do
    page = max(socket.assigns.current_page - 1, 1)
    {:noreply, assign(socket, current_page: page)}
  end

  def handle_event("next_page", _, socket) do
    total_pages =
      max(
        1,
        ceil(
          length(filtered_members(socket.assigns.members, socket.assigns.search_query)) /
            @per_page
        )
      )

    page = min(socket.assigns.current_page + 1, total_pages)
    {:noreply, assign(socket, current_page: page)}
  end

  # ── Invite Modal ──

  def handle_event("show_invite_modal", _, socket) do
    {:noreply,
     assign(socket,
       show_invite_modal: true,
       invite_error: nil,
       invite_emails: [],
       invite_email_input: "",
       invite_role: "member",
       invite_success_count: 0
     )}
  end

  def handle_event("close_invite_modal", _, socket) do
    {:noreply, assign(socket, show_invite_modal: false)}
  end

  def handle_event("add_invite_email", %{"email" => email}, socket) do
    email = String.trim(email)

    cond do
      email == "" ->
        {:noreply, socket}

      email in socket.assigns.invite_emails ->
        {:noreply, assign(socket, invite_error: "#{email} already added", invite_email_input: "")}

      length(socket.assigns.invite_emails) >= 10 ->
        {:noreply, assign(socket, invite_error: "Maximum 10 invites at once")}

      true ->
        {:noreply,
         assign(socket,
           invite_emails: socket.assigns.invite_emails ++ [email],
           invite_email_input: "",
           invite_error: nil
         )}
    end
  end

  def handle_event("remove_invite_email", %{"email" => email}, socket) do
    {:noreply, assign(socket, invite_emails: List.delete(socket.assigns.invite_emails, email))}
  end

  def handle_event("update_invite_email", %{"email" => email}, socket) do
    {:noreply, assign(socket, invite_email_input: email)}
  end

  def handle_event("update_invite_role", %{"role" => role}, socket) do
    {:noreply, assign(socket, invite_role: role)}
  end

  def handle_event("send_invites", _, socket) do
    org_id = socket.assigns.org_id
    role = validated_role(socket.assigns.invite_role)

    # Include any email still in the input field
    pending = String.trim(socket.assigns.invite_email_input)
    emails = socket.assigns.invite_emails
    emails = if pending != "" and pending not in emails, do: emails ++ [pending], else: emails

    if emails == [] do
      {:noreply, assign(socket, invite_error: "Enter an email address")}
    else
      {success, errors} = process_invites(emails, org_id, role)

      if errors == [] do
        members = reload_members(org_id)

        {:noreply,
         socket
         |> assign(show_invite_modal: false, members: members, used_seats: length(members))
         |> put_flash(:info, "#{success} member(s) added to team")}
      else
        members = reload_members(org_id)

        {:noreply,
         assign(socket,
           invite_error: Enum.join(errors, ". "),
           invite_success_count: success,
           invite_emails: [],
           members: members,
           used_seats: length(members)
         )}
      end
    end
  end

  # ── Member Actions ──

  def handle_event("delete_member", %{"id" => id}, socket) do
    case Ash.get(FounderPad.Accounts.Membership, id) do
      {:ok, membership} ->
        membership |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy()
        members = reload_members(socket.assigns.org_id)

        {:noreply,
         socket
         |> assign(members: members, used_seats: length(members))
         |> put_flash(:info, "Member removed")}

      _ ->
        {:noreply, put_flash(socket, :error, "Member not found")}
    end
  end

  def handle_event("start_role_edit", %{"id" => id}, socket) do
    {:noreply, assign(socket, role_edit_id: id)}
  end

  def handle_event("cancel_role_edit", _, socket) do
    {:noreply, assign(socket, role_edit_id: nil)}
  end

  def handle_event("change_role", %{"id" => id, "role" => role}, socket) do
    case Ash.get(FounderPad.Accounts.Membership, id) do
      {:ok, membership} ->
        case membership
             |> Ash.Changeset.for_update(:change_role, %{role: validated_role(role)})
             |> Ash.update() do
          {:ok, _} ->
            members = reload_members(socket.assigns.org_id)

            {:noreply,
             socket
             |> assign(members: members, role_edit_id: nil)
             |> put_flash(:info, "Role updated")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update role")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Member not found")}
    end
  end

  # ── Seats Modal ──

  def handle_event("show_seats_modal", _, socket) do
    {:noreply, assign(socket, show_seats_modal: true, new_seat_count: socket.assigns.total_seats)}
  end

  def handle_event("close_seats_modal", _, socket) do
    {:noreply, assign(socket, show_seats_modal: false)}
  end

  def handle_event("increment_seats", _, socket) do
    {:noreply, assign(socket, new_seat_count: socket.assigns.new_seat_count + 1)}
  end

  def handle_event("decrement_seats", _, socket) do
    new = max(socket.assigns.used_seats, socket.assigns.new_seat_count - 1)
    {:noreply, assign(socket, new_seat_count: new)}
  end

  def handle_event("save_seats", _, socket) do
    {:noreply,
     socket
     |> assign(total_seats: socket.assigns.new_seat_count, show_seats_modal: false)
     |> put_flash(:info, "Seats updated to #{socket.assigns.new_seat_count}")}
  end

  # ── Render ──

  def render(assigns) do
    filtered = filtered_members(assigns.members, assigns.search_query)
    total_pages = max(1, ceil(length(filtered) / @per_page))
    page_start = (assigns.current_page - 1) * @per_page
    paginated = Enum.slice(filtered, page_start, @per_page)

    assigns =
      assigns
      |> Map.put(:filtered, filtered)
      |> Map.put(:paginated, paginated)
      |> Map.put(:total_pages, total_pages)

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
            Manage permissions, invite collaborators, and oversee team access across your workspace.
          </p>
        </div>
        <button
          phx-click="show_invite_modal"
          class="primary-gradient text-on-primary px-6 py-3 rounded-lg flex items-center gap-2 font-label font-semibold text-xs tracking-wider uppercase editorial-shadow hover:scale-[1.02] transition-transform whitespace-nowrap"
        >
          <span class="material-symbols-outlined text-sm">person_add</span> Invite Members
        </button>
      </div>

      <%!-- Stats Row --%>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
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
              style={"width: #{min(round(@used_seats / max(@total_seats, 1) * 100), 100)}%"}
            >
            </div>
          </div>
        </div>

        <div class="bg-surface-container rounded-xl p-5">
          <p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50 mb-2">
            Active Now
          </p>
          <div class="flex items-center gap-3">
            <span class="font-mono text-2xl font-bold text-on-surface">{@active_now}</span>
            <span class="flex items-center gap-1.5">
              <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              <span class="text-[10px] font-semibold uppercase tracking-wider text-emerald-500">
                Live
              </span>
            </span>
          </div>
        </div>

        <div class="bg-surface-container rounded-xl p-5">
          <p class="font-label text-[10px] font-bold uppercase tracking-widest text-on-surface-variant/50 mb-2">
            Pending
          </p>
          <span class="font-mono text-2xl font-bold text-on-surface">
            {String.pad_leading("#{@pending}", 2, "0")}
          </span>
        </div>

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
          phx-keyup="live_search"
          phx-debounce="200"
          class="w-full pl-12 pr-4 py-3.5 bg-surface-container rounded-xl border border-outline-variant/20 text-sm text-on-surface placeholder-on-surface-variant/40 focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary/50 transition-all"
        />
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
              <tr :if={@paginated == []} class="border-b border-outline-variant/5">
                <td colspan="5" class="px-6 py-12 text-center text-on-surface-variant">
                  <span class="material-symbols-outlined text-4xl text-on-surface-variant/30 mb-2 block">
                    group_off
                  </span>
                  <p class="text-sm">
                    {if @search_query != "",
                      do: "No members matching \"#{@search_query}\"",
                      else: "No team members yet"}
                  </p>
                </td>
              </tr>
              <tr
                :for={m <- @paginated}
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

                <%!-- Role (editable) --%>
                <td class="px-6 py-4">
                  <%= if @role_edit_id == m.id do %>
                    <form phx-submit="change_role" phx-value-id={m.id} class="flex items-center gap-2">
                      <input type="hidden" name="id" value={m.id} />
                      <select
                        name="role"
                        class="bg-surface-container-highest border-none rounded-lg px-2 py-1 text-xs text-on-surface focus:ring-2 focus:ring-primary"
                      >
                        <option value="member" selected={m.role == :member}>Member</option>
                        <option value="admin" selected={m.role == :admin}>Admin</option>
                        <option value="owner" selected={m.role == :owner}>Owner</option>
                      </select>
                      <button type="submit" class="text-primary hover:text-primary/80">
                        <span class="material-symbols-outlined text-lg">check</span>
                      </button>
                      <button
                        type="button"
                        phx-click="cancel_role_edit"
                        class="text-on-surface-variant hover:text-on-surface"
                      >
                        <span class="material-symbols-outlined text-lg">close</span>
                      </button>
                    </form>
                  <% else %>
                    <span class={[
                      "inline-flex px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider",
                      role_badge_class(m.role)
                    ]}>
                      {role_label(m.role)}
                    </span>
                  <% end %>
                </td>

                <%!-- Status --%>
                <td class="px-6 py-4">
                  <div class="flex items-center gap-2">
                    <span class={["w-2 h-2 rounded-full", status_dot_class(m.status)]}></span>
                    <span class="font-body text-xs text-on-surface-variant">
                      {status_label(m.status)}
                    </span>
                  </div>
                </td>

                <%!-- Last Active --%>
                <td class="px-6 py-4">
                  <span class="font-mono text-xs text-on-surface-variant/50">{m.last_active}</span>
                </td>

                <%!-- Actions --%>
                <td class="px-6 py-4 text-right">
                  <%= if m.role == :owner && @current_user_role == :owner do %>
                    <button
                      phx-click="show_seats_modal"
                      class="px-3 py-1.5 rounded-lg bg-surface-container-highest/50 text-[10px] font-bold uppercase tracking-wider text-on-surface-variant hover:bg-surface-container-highest hover:text-primary transition-colors"
                    >
                      Manage Seats
                    </button>
                  <% else %>
                    <div class="flex items-center justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button
                        phx-click="start_role_edit"
                        phx-value-id={m.id}
                        class="p-1.5 rounded-lg text-on-surface-variant/40 hover:text-primary hover:bg-primary/5 transition-all"
                        title="Change role"
                      >
                        <span class="material-symbols-outlined text-lg">edit</span>
                      </button>
                      <button
                        phx-click="delete_member"
                        phx-value-id={m.id}
                        data-confirm="Remove this member from the team?"
                        class="p-1.5 rounded-lg text-on-surface-variant/40 hover:text-error hover:bg-error/5 transition-all"
                        title="Remove member"
                      >
                        <span class="material-symbols-outlined text-lg">delete</span>
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
            Showing {min((@current_page - 1) * 6 + 1, length(@filtered))}-{min(
              @current_page * 6,
              length(@filtered)
            )} of {length(@filtered)} members
          </span>
          <div class="flex items-center gap-1">
            <button
              phx-click="prev_page"
              disabled={@current_page == 1}
              class="w-8 h-8 rounded-lg flex items-center justify-center text-on-surface-variant/40 hover:bg-surface-container-high transition-colors disabled:opacity-30"
            >
              <span class="material-symbols-outlined text-sm">chevron_left</span>
            </button>
            <button
              :for={p <- 1..@total_pages}
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
            <button
              phx-click="next_page"
              disabled={@current_page >= @total_pages}
              class="w-8 h-8 rounded-lg flex items-center justify-center text-on-surface-variant/40 hover:bg-surface-container-high transition-colors disabled:opacity-30"
            >
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
              Member activity and permission changes are logged for compliance.
            </p>
          </div>
        </div>
        <.link
          navigate="/activity"
          class="flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-primary hover:text-primary/80 transition-colors whitespace-nowrap"
        >
          View Audit Trail <span class="material-symbols-outlined text-sm">arrow_forward</span>
        </.link>
      </div>

      <%!-- ═══ Enhanced Invite Modal ═══ --%>
      <div
        :if={@show_invite_modal}
        class="fixed inset-0 z-50 flex items-center justify-center bg-background/80 backdrop-blur-sm"
      >
        <div class="bg-surface-container rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden">
          <%!-- Modal Header --%>
          <div class="px-8 pt-8 pb-4">
            <div class="flex justify-between items-center mb-2">
              <h2 class="text-xl font-bold font-headline text-on-surface">Invite Team Members</h2>
              <button
                phx-click="close_invite_modal"
                class="p-1 text-on-surface-variant hover:text-on-surface rounded-lg hover:bg-surface-container-high transition-colors"
              >
                <span class="material-symbols-outlined">close</span>
              </button>
            </div>
            <p class="text-xs text-on-surface-variant">
              Add up to 10 people at once. They must have a FounderPad account.
            </p>
          </div>

          <%!-- Seat availability --%>
          <div class="mx-8 mb-4 flex items-center gap-3 px-4 py-3 bg-surface-container-high/50 rounded-xl">
            <span class="material-symbols-outlined text-primary text-lg">event_seat</span>
            <div class="flex-1">
              <p class="text-xs font-medium text-on-surface">
                {@total_seats - @used_seats} seat(s) available
              </p>
              <div class="mt-1.5 h-1 bg-surface-container-highest rounded-full overflow-hidden">
                <div
                  class="h-full bg-primary rounded-full"
                  style={"width: #{min(round(@used_seats / max(@total_seats, 1) * 100), 100)}%"}
                >
                </div>
              </div>
            </div>
            <span class="text-[10px] font-mono text-on-surface-variant">
              {@used_seats}/{@total_seats}
            </span>
          </div>

          <div class="px-8 pb-8 space-y-5">
            <%!-- Error/Success messages --%>
            <div
              :if={@invite_error}
              class="flex items-start gap-2 bg-error/10 text-error text-sm p-3 rounded-lg"
            >
              <span class="material-symbols-outlined text-base mt-0.5">error</span>
              <span>{@invite_error}</span>
            </div>
            <div
              :if={@invite_success_count > 0 && @invite_error}
              class="flex items-start gap-2 bg-primary/10 text-primary text-sm p-3 rounded-lg"
            >
              <span class="material-symbols-outlined text-base mt-0.5">check_circle</span>
              <span>{@invite_success_count} member(s) added successfully</span>
            </div>

            <%!-- Email input with add button --%>
            <form
              id="add-email-form"
              phx-submit="add_invite_email"
              phx-change="update_invite_email"
              class="flex gap-2"
            >
              <div class="flex-1 relative">
                <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant/40 text-lg">
                  mail
                </span>
                <input
                  type="email"
                  name="email"
                  value={@invite_email_input}
                  placeholder="colleague@company.com"
                  class="w-full pl-10 pr-4 bg-surface-container-highest border-none rounded-lg py-3 text-sm text-on-surface focus:ring-2 focus:ring-primary placeholder:text-on-surface-variant/40"
                />
              </div>
              <button
                type="submit"
                class="px-4 py-3 bg-surface-container-highest hover:bg-primary/10 text-primary rounded-lg text-sm font-semibold transition-colors flex items-center gap-1"
              >
                <span class="material-symbols-outlined text-lg">add</span> Add
              </button>
            </form>

            <%!-- Email chips --%>
            <div :if={@invite_emails != []} class="flex flex-wrap gap-2">
              <span
                :for={email <- @invite_emails}
                class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-primary/10 text-primary text-xs font-medium rounded-full group/chip"
              >
                <span class="material-symbols-outlined text-[12px]">person</span>
                {email}
                <button
                  type="button"
                  phx-click="remove_invite_email"
                  phx-value-email={email}
                  class="ml-0.5 hover:text-error transition-colors"
                >
                  <span class="material-symbols-outlined text-[14px]">close</span>
                </button>
              </span>
            </div>

            <%!-- Role selector with descriptions --%>
            <div>
              <label class="text-xs font-bold uppercase tracking-wider text-on-surface-variant mb-3 block">
                Assign Role
              </label>
              <div class="grid grid-cols-3 gap-3">
                <button
                  :for={
                    {role_key, role_name, role_desc, role_icon} <- [
                      {"member", "Member", "View & use agents", "person"},
                      {"admin", "Admin", "Manage agents & team", "shield_person"},
                      {"owner", "Owner", "Full access & billing", "admin_panel_settings"}
                    ]
                  }
                  type="button"
                  phx-click="update_invite_role"
                  phx-value-role={role_key}
                  class={[
                    "p-3 rounded-xl text-left transition-all border-2",
                    if(@invite_role == role_key,
                      do: "border-primary bg-primary/5",
                      else: "border-transparent bg-surface-container-high/50 hover:border-primary/20"
                    )
                  ]}
                >
                  <span class={[
                    "material-symbols-outlined text-lg mb-1 block",
                    if(@invite_role == role_key, do: "text-primary", else: "text-on-surface-variant")
                  ]}>
                    {role_icon}
                  </span>
                  <p class="text-xs font-bold text-on-surface">{role_name}</p>
                  <p class="text-[10px] text-on-surface-variant mt-0.5">{role_desc}</p>
                </button>
              </div>
            </div>

            <%!-- Submit --%>
            <button
              phx-click="send_invites"
              class="w-full primary-gradient py-3 rounded-lg text-sm font-bold transition-all flex items-center justify-center gap-2"
            >
              <span class="material-symbols-outlined text-lg">group_add</span>
              {if length(@invite_emails) > 0,
                do: "Add #{length(@invite_emails)} Member(s)",
                else: "Add Member"}
            </button>
          </div>
        </div>
      </div>

      <%!-- ═══ Manage Seats Modal ═══ --%>
      <div
        :if={@show_seats_modal}
        class="fixed inset-0 z-50 flex items-center justify-center bg-background/80 backdrop-blur-sm"
      >
        <div class="bg-surface-container rounded-2xl p-8 w-full max-w-md shadow-2xl space-y-6">
          <div class="flex justify-between items-center">
            <h2 class="text-xl font-bold font-headline text-on-surface">Manage Seats</h2>
            <button
              phx-click="close_seats_modal"
              class="p-1 text-on-surface-variant hover:text-on-surface rounded-lg hover:bg-surface-container-high transition-colors"
            >
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>

          <div class="space-y-4">
            <div class="flex items-center justify-between p-4 bg-surface-container-high/50 rounded-xl">
              <div>
                <p class="text-sm font-bold text-on-surface">Current Plan</p>
                <p class="text-xs text-on-surface-variant">{@total_seats} seats included</p>
              </div>
              <span class="font-mono text-2xl font-bold text-primary">
                {@used_seats}<span class="text-sm text-on-surface-variant/40">/{@total_seats}</span>
              </span>
            </div>

            <div class="space-y-2">
              <div class="flex justify-between text-xs text-on-surface-variant">
                <span>Seats used</span>
                <span class="font-mono">
                  {min(round(@used_seats / max(@total_seats, 1) * 100), 100)}%
                </span>
              </div>
              <div class="h-2 bg-surface-container-highest rounded-full overflow-hidden">
                <div
                  class={[
                    "h-full rounded-full transition-all",
                    if(@used_seats / max(@total_seats, 1) > 0.8, do: "bg-error", else: "bg-primary")
                  ]}
                  style={"width: #{min(round(@used_seats / max(@total_seats, 1) * 100), 100)}%"}
                >
                </div>
              </div>
            </div>

            <%!-- Adjust Seats Controls --%>
            <div class="p-4 bg-surface-container-high/50 rounded-xl">
              <p class="text-xs font-bold uppercase tracking-wider text-on-surface-variant mb-3">
                Adjust Seats
              </p>
              <div class="flex items-center justify-center gap-4">
                <button
                  phx-click="decrement_seats"
                  disabled={@new_seat_count <= @used_seats}
                  class="w-10 h-10 rounded-lg bg-surface-container-highest flex items-center justify-center text-on-surface hover:bg-error/10 hover:text-error transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
                >
                  <span class="material-symbols-outlined text-xl">remove</span>
                </button>
                <span class="font-mono text-3xl font-bold text-on-surface min-w-[3ch] text-center">
                  {@new_seat_count}
                </span>
                <button
                  phx-click="increment_seats"
                  class="w-10 h-10 rounded-lg bg-surface-container-highest flex items-center justify-center text-on-surface hover:bg-primary/10 hover:text-primary transition-colors"
                >
                  <span class="material-symbols-outlined text-xl">add</span>
                </button>
              </div>
              <p
                :if={@new_seat_count != @total_seats}
                class="text-center text-xs text-on-surface-variant mt-2"
              >
                {if @new_seat_count > @total_seats,
                  do: "Adding #{@new_seat_count - @total_seats} seat(s)",
                  else: "Removing #{@total_seats - @new_seat_count} seat(s)"}
              </p>
            </div>

            <div class="p-4 bg-primary/5 rounded-xl">
              <p class="text-xs text-on-surface-variant leading-relaxed">
                <span class="material-symbols-outlined text-primary text-sm align-middle mr-1">
                  info
                </span>
                Seat changes will be reflected in your next billing cycle.
                Visit the
                <.link navigate="/billing" class="text-primary font-semibold hover:underline">
                  Billing page
                </.link>
                for plan details.
              </p>
            </div>
          </div>

          <div class="flex gap-3">
            <button
              phx-click="close_seats_modal"
              class="flex-1 bg-surface-container-highest hover:bg-surface-container-high text-on-surface py-3 rounded-lg text-sm font-semibold transition-colors"
            >
              Cancel
            </button>
            <button
              phx-click="save_seats"
              disabled={@new_seat_count == @total_seats}
              class="flex-1 primary-gradient text-on-primary py-3 rounded-lg text-sm font-semibold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Save Changes
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ──

  defp per_page, do: @per_page

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
  defp avatar_bg_class(:admin), do: "bg-secondary/10 text-secondary"
  defp avatar_bg_class(_), do: "bg-surface-container-highest text-on-surface-variant"

  defp role_badge_class(:owner), do: "bg-primary/10 text-primary"
  defp role_badge_class(:admin), do: "bg-secondary/10 text-secondary"
  defp role_badge_class(_), do: "bg-surface-container-highest text-on-surface-variant"

  defp role_label(:owner), do: "Owner"
  defp role_label(:admin), do: "Admin"
  defp role_label(:member), do: "Member"
  defp role_label(r), do: r |> to_string() |> String.capitalize()

  defp status_dot_class(:active), do: "bg-emerald-500"
  defp status_dot_class(_), do: "bg-outline-variant/60"

  defp status_label(:active), do: "Active"
  defp status_label(_), do: "Offline"

  defp get_user_org_id(nil), do: nil

  defp get_user_org_id(user) do
    case FounderPad.Accounts.Membership
         |> Ash.Query.filter(user_id: user.id)
         |> Ash.Query.limit(1)
         |> Ash.read() do
      {:ok, [m | _]} -> m.organisation_id
      _ -> nil
    end
  end

  defp get_current_user_role(nil, _), do: :member

  defp get_current_user_role(user, org_id) when not is_nil(org_id) do
    case FounderPad.Accounts.Membership
         |> Ash.Query.filter(user_id: user.id)
         |> Ash.Query.filter(organisation_id: org_id)
         |> Ash.read() do
      {:ok, [m | _]} -> m.role
      _ -> :member
    end
  end

  defp get_current_user_role(_, _), do: :member

  @valid_roles ~w(owner admin member viewer)
  defp validated_role(role) when role in @valid_roles, do: String.to_existing_atom(role)
  defp validated_role(_), do: :member

  defp reload_members(nil), do: []

  defp reload_members(org_id) do
    case FounderPad.Accounts.Membership
         |> Ash.Query.filter(organisation_id == ^org_id)
         |> Ash.Query.load([:user])
         |> Ash.read() do
      {:ok, memberships} -> Enum.map(memberships, &format_member/1)
      _ -> []
    end
  end

  defp load_plan(nil), do: nil

  defp load_plan(_org_id) do
    case FounderPad.Billing.Plan |> Ash.Query.sort(sort_order: :asc) |> Ash.read() do
      {:ok, [plan | _]} -> plan
      _ -> nil
    end
  end

  defp next_billing_date do
    today = Date.utc_today()
    next_month = Date.add(today, 30 - today.day + 1)
    Calendar.strftime(next_month, "%b %d")
  end

  defp process_invites(emails, org_id, role) do
    Enum.reduce(emails, {0, []}, fn email, {success, errors} ->
      case FounderPad.Accounts.User |> Ash.Query.filter(email == ^email) |> Ash.read() do
        {:ok, [user | _]} ->
          case FounderPad.Accounts.Membership
               |> Ash.Changeset.for_create(:create, %{
                 role: role,
                 user_id: user.id,
                 organisation_id: org_id
               })
               |> Ash.create() do
            {:ok, _} -> {success + 1, errors}
            {:error, _} -> {success, errors ++ ["#{email}: already a member"]}
          end

        _ ->
          {success, errors ++ ["#{email}: no account found"]}
      end
    end)
  end

  defp format_member(membership) do
    user = membership.user

    %{
      id: membership.id,
      name: user.name || "Unnamed User",
      email: to_string(user.email),
      role: membership.role,
      status: :active,
      last_active: Calendar.strftime(membership.updated_at, "%Y-%m-%d %H:%M:%S"),
      avatar: user.avatar_url
    }
  end
end
