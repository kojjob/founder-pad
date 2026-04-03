defmodule FounderPadWeb.ApiKeysLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    memberships =
      FounderPad.Accounts.Membership
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.load([:organisation])
      |> Ash.read!()

    org =
      case memberships do
        [m | _] -> m.organisation
        [] -> nil
      end

    keys = load_keys(org)

    {:ok,
     assign(socket,
       page_title: "API Keys",
       active_nav: :api_keys,
       keys: keys,
       org: org,
       new_raw_key: nil,
       show_create: false
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
            API Keys
          </h1>
          <p class="text-on-surface-variant mt-2">
            Manage API keys for programmatic access to your organisation's resources.
          </p>
        </div>
        <button
          :if={@org && !@show_create}
          phx-click="show_create"
          class="primary-gradient px-5 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95 flex items-center gap-2 whitespace-nowrap"
        >
          <span class="material-symbols-outlined text-lg">add</span> New API Key
        </button>
      </div>

      <%!-- New key reveal banner --%>
      <div
        :if={@new_raw_key}
        class="bg-green-50 border border-green-200 rounded-xl p-6 space-y-3"
      >
        <div class="flex items-start gap-3">
          <span class="material-symbols-outlined text-green-600 mt-0.5">key</span>
          <div class="flex-1">
            <p class="font-semibold text-green-800">Your new API key</p>
            <p class="text-sm text-green-700 mt-1">
              Copy this key now. You will not be able to see it again.
            </p>
            <code class="block mt-3 p-3 bg-white rounded-lg border border-green-200 text-sm font-mono text-green-900 break-all">
              {@new_raw_key}
            </code>
          </div>
        </div>
        <div class="flex justify-end">
          <button
            phx-click="dismiss_key"
            class="text-sm px-4 py-2 rounded-md bg-green-100 text-green-700 hover:bg-green-200 transition-colors"
          >
            I've copied my key
          </button>
        </div>
      </div>

      <%!-- Create form --%>
      <div :if={@show_create} class="bg-surface-container rounded-xl p-6 space-y-4">
        <h2 class="text-lg font-semibold text-on-surface">Create New API Key</h2>
        <form phx-submit="create" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-on-surface-variant mb-1">Name</label>
            <input
              type="text"
              name="name"
              required
              placeholder="e.g. Production Key"
              class="w-full px-4 py-2.5 rounded-lg border border-outline-variant/30 bg-surface-container text-on-surface placeholder:text-on-surface-variant/50 focus:ring-2 focus:ring-primary/20 focus:border-primary transition-colors"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-on-surface-variant mb-2">Scopes</label>
            <div class="flex gap-4">
              <label :for={scope <- [:read, :write, :admin]} class="flex items-center gap-2">
                <input
                  type="checkbox"
                  name="scopes[]"
                  value={scope}
                  checked={scope == :read}
                  class="rounded border-outline-variant/30 text-primary focus:ring-primary/20"
                />
                <span class="text-sm text-on-surface">{scope |> Atom.to_string() |> String.capitalize()}</span>
              </label>
            </div>
          </div>
          <div class="flex gap-3 pt-2">
            <button
              type="submit"
              class="primary-gradient px-5 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95"
            >
              Create Key
            </button>
            <button
              type="button"
              phx-click="cancel_create"
              class="px-5 py-2.5 rounded-lg text-sm font-semibold text-on-surface-variant hover:bg-surface-container-highest transition-colors"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>

      <%!-- Keys table --%>
      <div class="bg-surface-container rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Name
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Prefix
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Scopes
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Last Used
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Created
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Status
              </th>
              <th class="text-right px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={key <- @keys}
              class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
            >
              <td class="px-6 py-4 font-medium text-on-surface">
                {key.name}
              </td>
              <td class="px-6 py-4">
                <code class="text-sm font-mono text-on-surface-variant">{key.key_prefix}...</code>
              </td>
              <td class="px-6 py-4">
                <div class="flex gap-1">
                  <span
                    :for={scope <- key.scopes}
                    class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-surface-container-highest text-on-surface-variant"
                  >
                    {scope}
                  </span>
                </div>
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {if key.last_used_at,
                  do: Calendar.strftime(key.last_used_at, "%b %d, %Y"),
                  else: "Never"}
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {Calendar.strftime(key.inserted_at, "%b %d, %Y")}
              </td>
              <td class="px-6 py-4">
                <span
                  :if={key.revoked_at}
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700"
                >
                  Revoked
                </span>
                <span
                  :if={!key.revoked_at}
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700"
                >
                  Active
                </span>
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center justify-end gap-2">
                  <button
                    :if={!key.revoked_at}
                    phx-click="revoke"
                    phx-value-id={key.id}
                    data-confirm="Are you sure you want to revoke this API key? This cannot be undone."
                    class="text-xs px-3 py-1.5 rounded-md bg-red-50 text-red-700 hover:bg-red-100 transition-colors"
                  >
                    Revoke
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <div
          :if={@keys == []}
          class="px-6 py-16 text-center text-on-surface-variant"
        >
          <span class="material-symbols-outlined text-4xl opacity-30 block mb-2">vpn_key</span>
          <p>No API keys yet. Create one to get started.</p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("show_create", _params, socket) do
    {:noreply, assign(socket, show_create: true)}
  end

  def handle_event("cancel_create", _params, socket) do
    {:noreply, assign(socket, show_create: false)}
  end

  def handle_event("create", %{"name" => name} = params, socket) do
    user = socket.assigns.current_user
    org = socket.assigns.org

    scopes =
      params
      |> Map.get("scopes", ["read"])
      |> Enum.map(&String.to_existing_atom/1)

    result =
      FounderPad.ApiKeys.ApiKey
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        scopes: scopes,
        organisation_id: org.id,
        created_by_id: user.id
      })
      |> Ash.create!()

    raw_key = Map.get(result, :__raw_key__)

    {:noreply,
     socket
     |> assign(
       new_raw_key: raw_key,
       show_create: false,
       keys: load_keys(org)
     )
     |> put_flash(:info, "API key created.")}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    key = Ash.get!(FounderPad.ApiKeys.ApiKey, id)

    key
    |> Ash.Changeset.for_update(:revoke, %{})
    |> Ash.update!()

    {:noreply,
     socket
     |> put_flash(:info, "API key revoked.")
     |> assign(keys: load_keys(socket.assigns.org))}
  end

  def handle_event("dismiss_key", _params, socket) do
    {:noreply, assign(socket, new_raw_key: nil)}
  end

  defp load_keys(nil), do: []

  defp load_keys(org) do
    FounderPad.ApiKeys.ApiKey
    |> Ash.Query.for_read(:by_organisation, %{organisation_id: org.id})
    |> Ash.Query.load([:created_by])
    |> Ash.read!()
  end
end
