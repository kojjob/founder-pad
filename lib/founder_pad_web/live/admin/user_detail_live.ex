defmodule FounderPadWeb.Admin.UserDetailLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(%{"id" => id}, _session, socket) do
    admin = socket.assigns.current_user
    user = load_user(id, admin)

    {:ok,
     assign(socket,
       page_title: "User: #{user.email} — Admin",
       active_nav: :admin_users,
       user: user
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-4xl mx-auto">
      <div class="flex items-center gap-3">
        <a
          href="/admin/users"
          class="text-on-surface-variant hover:text-on-surface transition-colors"
        >
          <span class="material-symbols-outlined">arrow_back</span>
        </a>
        <h1 class="text-2xl font-bold font-heading text-on-surface">User Detail</h1>
      </div>

      <div class="bg-white rounded-2xl border border-neutral-200/60 p-8">
        <div class="flex items-start gap-6">
          <div :if={@user.avatar_url} class="flex-shrink-0">
            <img
              src={@user.avatar_url}
              alt="Avatar"
              class="w-20 h-20 rounded-full object-cover border-2 border-neutral-200"
            />
          </div>
          <div
            :if={!@user.avatar_url}
            class="flex-shrink-0 w-20 h-20 rounded-full bg-primary/10 flex items-center justify-center"
          >
            <span class="material-symbols-outlined text-3xl text-primary">person</span>
          </div>
          <div class="flex-1 space-y-4">
            <div>
              <h2 class="text-xl font-bold text-on-surface">{@user.name || "No name set"}</h2>
              <p class="text-on-surface-variant">{@user.email}</p>
            </div>

            <div class="flex flex-wrap gap-2">
              <span
                :if={@user.is_admin}
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-700"
              >
                Admin
              </span>
              <span
                :if={@user.suspended_at}
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700"
              >
                Suspended {Calendar.strftime(@user.suspended_at, "%b %d, %Y")}
              </span>
              <span
                :if={!@user.suspended_at}
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700"
              >
                Active
              </span>
            </div>

            <div class="grid grid-cols-2 gap-4 text-sm">
              <div>
                <p class="text-on-surface-variant">Created</p>
                <p class="text-on-surface font-medium">
                  {Calendar.strftime(@user.inserted_at, "%b %d, %Y at %I:%M %p")}
                </p>
              </div>
              <div>
                <p class="text-on-surface-variant">Confirmed</p>
                <p class="text-on-surface font-medium">
                  {if @user.confirmed_at,
                    do: Calendar.strftime(@user.confirmed_at, "%b %d, %Y"),
                    else: "Not confirmed"}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-2xl border border-neutral-200/60 p-8">
        <h3 class="text-lg font-bold font-heading text-on-surface mb-4">Memberships</h3>
        <div :if={@user.memberships == [] || !Ash.Resource.loaded?(@user, :memberships)} class="text-on-surface-variant">
          No memberships found.
        </div>
        <table :if={@user.memberships != [] && Ash.Resource.loaded?(@user, :memberships)} class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-4 py-3 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Organisation
              </th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Role
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={membership <- @user.memberships}
              class="border-b border-outline-variant/10"
            >
              <td class="px-4 py-3 text-sm text-on-surface">
                {if Ash.Resource.loaded?(membership, :organisation),
                  do: membership.organisation.name,
                  else: membership.organisation_id}
              </td>
              <td class="px-4 py-3 text-sm text-on-surface-variant">
                <span class="capitalize">{membership.role}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="bg-white rounded-2xl border border-neutral-200/60 p-8">
        <h3 class="text-lg font-bold font-heading text-on-surface mb-4">Actions</h3>
        <div class="flex flex-wrap gap-3">
          <button
            :if={!@user.suspended_at}
            phx-click="suspend"
            phx-value-id={@user.id}
            data-confirm="Are you sure you want to suspend this user?"
            class="px-4 py-2 rounded-lg text-sm font-semibold bg-red-50 text-red-700 hover:bg-red-100 transition-colors"
          >
            Suspend User
          </button>
          <button
            :if={@user.suspended_at}
            phx-click="unsuspend"
            phx-value-id={@user.id}
            class="px-4 py-2 rounded-lg text-sm font-semibold bg-green-50 text-green-700 hover:bg-green-100 transition-colors"
          >
            Unsuspend User
          </button>
          <button
            phx-click="toggle_admin"
            phx-value-id={@user.id}
            data-confirm={"Are you sure you want to #{if @user.is_admin, do: "remove admin from", else: "make admin"} this user?"}
            class="px-4 py-2 rounded-lg text-sm font-semibold bg-purple-50 text-purple-700 hover:bg-purple-100 transition-colors"
          >
            {if @user.is_admin, do: "Remove Admin", else: "Make Admin"}
          </button>
          <button
            phx-click="impersonate"
            phx-value-id={@user.id}
            class="px-4 py-2 rounded-lg text-sm font-semibold bg-amber-50 text-amber-700 hover:bg-amber-100 transition-colors"
          >
            Impersonate
          </button>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("suspend", %{"id" => id}, socket) do
    admin = socket.assigns.current_user
    user = Ash.get!(FounderPad.Accounts.User, id, actor: admin)

    user
    |> Ash.Changeset.for_update(:suspend, %{}, actor: admin)
    |> Ash.update!()

    {:noreply,
     socket
     |> put_flash(:info, "User suspended.")
     |> assign(user: load_user(id, admin))}
  end

  def handle_event("unsuspend", %{"id" => id}, socket) do
    admin = socket.assigns.current_user
    user = Ash.get!(FounderPad.Accounts.User, id, actor: admin)

    user
    |> Ash.Changeset.for_update(:unsuspend, %{}, actor: admin)
    |> Ash.update!()

    {:noreply,
     socket
     |> put_flash(:info, "User unsuspended.")
     |> assign(user: load_user(id, admin))}
  end

  def handle_event("toggle_admin", %{"id" => id}, socket) do
    admin = socket.assigns.current_user
    user = Ash.get!(FounderPad.Accounts.User, id, actor: admin)

    user
    |> Ash.Changeset.for_update(:toggle_admin, %{}, actor: admin)
    |> Ash.update!()

    {:noreply,
     socket
     |> put_flash(:info, "Admin status updated.")
     |> assign(user: load_user(id, admin))}
  end

  def handle_event("impersonate", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: "/admin/impersonate/#{id}")}
  end

  defp load_user(id, admin) do
    FounderPad.Accounts.User
    |> Ash.get!(id, actor: admin)
    |> Ash.load!([:memberships], actor: admin)
    |> then(fn user ->
      memberships =
        Enum.map(user.memberships, fn m ->
          Ash.load!(m, [:organisation])
        end)

      %{user | memberships: memberships}
    end)
  end
end
