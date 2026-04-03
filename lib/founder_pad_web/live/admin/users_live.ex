defmodule FounderPadWeb.Admin.UsersLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    admin = socket.assigns.current_user
    users = load_users(admin)

    {:ok,
     assign(socket,
       page_title: "Users — Admin",
       active_nav: :admin_users,
       users: users,
       search_query: ""
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
            Users
          </h1>
          <p class="text-on-surface-variant mt-2">
            Manage user accounts. Suspend, unsuspend, or view details.
          </p>
        </div>
      </div>

      <form phx-change="search" class="max-w-md">
        <input
          type="text"
          name="query"
          value={@search_query}
          placeholder="Search by email or name..."
          phx-debounce="300"
          class="w-full px-4 py-2.5 rounded-lg border border-outline-variant/30 bg-surface-container text-on-surface placeholder:text-on-surface-variant/50 focus:ring-2 focus:ring-primary/20 focus:border-primary transition-colors"
        />
      </form>

      <div class="bg-surface-container rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Email
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Name
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Role
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Status
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Created
              </th>
              <th class="text-right px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={user <- filtered_users(@users, @search_query)}
              class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
            >
              <td class="px-6 py-4">
                <a
                  href={"/admin/users/#{user.id}"}
                  class="font-medium text-primary hover:underline"
                >
                  {user.email}
                </a>
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {user.name || "—"}
              </td>
              <td class="px-6 py-4">
                <span
                  :if={user.is_admin}
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-700"
                >
                  Admin
                </span>
                <span
                  :if={!user.is_admin}
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-neutral-100 text-neutral-600"
                >
                  User
                </span>
              </td>
              <td class="px-6 py-4">
                <span
                  :if={user.suspended_at}
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700"
                >
                  Suspended
                </span>
                <span
                  :if={!user.suspended_at}
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700"
                >
                  Active
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {Calendar.strftime(user.inserted_at, "%b %d, %Y")}
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center justify-end gap-2">
                  <a
                    href={"/admin/users/#{user.id}"}
                    class="text-xs px-3 py-1.5 rounded-md bg-surface-container-highest text-on-surface hover:bg-primary/10 hover:text-primary transition-colors"
                  >
                    View
                  </a>
                  <button
                    :if={!user.suspended_at}
                    phx-click="suspend"
                    phx-value-id={user.id}
                    data-confirm="Are you sure you want to suspend this user?"
                    class="text-xs px-3 py-1.5 rounded-md bg-red-50 text-red-700 hover:bg-red-100 transition-colors"
                  >
                    Suspend
                  </button>
                  <button
                    :if={user.suspended_at}
                    phx-click="unsuspend"
                    phx-value-id={user.id}
                    class="text-xs px-3 py-1.5 rounded-md bg-green-50 text-green-700 hover:bg-green-100 transition-colors"
                  >
                    Unsuspend
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <div
          :if={filtered_users(@users, @search_query) == []}
          class="px-6 py-16 text-center text-on-surface-variant"
        >
          <span class="material-symbols-outlined text-4xl opacity-30 block mb-2">person_off</span>
          <p>No users found.</p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
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
     |> assign(users: load_users(admin))}
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
     |> assign(users: load_users(admin))}
  end

  defp load_users(admin) do
    FounderPad.Accounts.User
    |> Ash.Query.for_read(:list_all, %{}, actor: admin)
    |> Ash.read!(actor: admin)
  end

  defp filtered_users(users, ""), do: users

  defp filtered_users(users, query) do
    q = String.downcase(query)

    Enum.filter(users, fn user ->
      String.contains?(String.downcase(to_string(user.email)), q) or
        String.contains?(String.downcase(to_string(user.name || "")), q)
    end)
  end
end
