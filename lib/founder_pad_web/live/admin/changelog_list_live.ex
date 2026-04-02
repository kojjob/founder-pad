defmodule FounderPadWeb.Admin.ChangelogListLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    entries = load_entries(socket.assigns.current_user)

    {:ok,
     assign(socket,
       page_title: "Changelog — Admin",
       active_nav: :admin_changelog,
       entries: entries
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <%!-- Header --%>
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
            Changelog Entries
          </h1>
          <p class="text-on-surface-variant mt-2">
            Manage changelog entries. Create, edit, publish, and delete release notes.
          </p>
        </div>
        <a
          href="/admin/changelog/new"
          class="primary-gradient px-5 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95 flex items-center gap-2 whitespace-nowrap"
        >
          <span class="material-symbols-outlined text-lg">add</span> New Entry
        </a>
      </div>

      <%!-- Entries Table --%>
      <div class="bg-surface-container rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Version
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Title
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Type
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Status
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Published
              </th>
              <th class="text-right px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={entry <- @entries}
              class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
            >
              <td class="px-6 py-4">
                <span class="font-mono text-sm font-bold text-primary">{entry.version}</span>
              </td>
              <td class="px-6 py-4">
                <div class="font-medium text-on-surface">{entry.title}</div>
              </td>
              <td class="px-6 py-4">
                <.type_badge type={entry.type} />
              </td>
              <td class="px-6 py-4">
                <.status_badge status={entry.status} />
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {if entry.published_at,
                  do: Calendar.strftime(entry.published_at, "%b %d, %Y"),
                  else: "—"}
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center justify-end gap-2">
                  <a
                    href={"/admin/changelog/#{entry.id}/edit"}
                    class="text-xs px-3 py-1.5 rounded-md bg-surface-container-highest text-on-surface hover:bg-primary/10 hover:text-primary transition-colors"
                  >
                    Edit
                  </a>
                  <button
                    :if={entry.status == :draft}
                    phx-click="publish"
                    phx-value-id={entry.id}
                    class="text-xs px-3 py-1.5 rounded-md bg-green-50 text-green-700 hover:bg-green-100 transition-colors"
                  >
                    Publish
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={entry.id}
                    data-confirm="Are you sure you want to delete this entry? This cannot be undone."
                    class="text-xs px-3 py-1.5 rounded-md bg-red-50 text-red-700 hover:bg-red-100 transition-colors"
                  >
                    Delete
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <div
          :if={@entries == []}
          class="px-6 py-16 text-center text-on-surface-variant"
        >
          <span class="material-symbols-outlined text-4xl opacity-30 block mb-2">history</span>
          <p>No changelog entries found.</p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("publish", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    entry = Ash.get!(FounderPad.Content.ChangelogEntry, id, actor: user)

    entry
    |> Ash.Changeset.for_update(:publish, %{}, actor: user)
    |> Ash.update!()

    {:noreply,
     socket
     |> put_flash(:info, "Entry published successfully.")
     |> assign(entries: load_entries(user))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    entry = Ash.get!(FounderPad.Content.ChangelogEntry, id, actor: user)

    entry
    |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
    |> Ash.destroy!()

    {:noreply,
     socket
     |> put_flash(:info, "Entry deleted.")
     |> assign(entries: load_entries(user))}
  end

  defp load_entries(user) do
    FounderPad.Content.ChangelogEntry
    |> Ash.Query.for_read(:read, %{}, actor: user)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: user)
  end

  defp type_badge(assigns) do
    {bg, label} =
      case assigns.type do
        :feature -> {"bg-indigo-100 text-indigo-700", "Feature"}
        :fix -> {"bg-green-100 text-green-700", "Fix"}
        :improvement -> {"bg-amber-100 text-amber-700", "Improvement"}
        :breaking -> {"bg-red-100 text-red-700", "Breaking"}
        _ -> {"bg-neutral-100 text-neutral-600", "Other"}
      end

    assigns = assign(assigns, bg: bg, label: label)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@bg}"}>
      {@label}
    </span>
    """
  end

  defp status_badge(assigns) do
    {bg, text} =
      case assigns.status do
        :draft -> {"bg-neutral-100 text-neutral-600", "Draft"}
        :published -> {"bg-green-100 text-green-700", "Published"}
        _ -> {"bg-neutral-100 text-neutral-600", "Unknown"}
      end

    assigns = assign(assigns, bg: bg, text: text)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@bg}"}>
      {@text}
    </span>
    """
  end
end
