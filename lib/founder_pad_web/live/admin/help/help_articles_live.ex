defmodule FounderPadWeb.Admin.HelpArticlesLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    articles = load_articles(user)
    categories = load_categories(user)

    {:ok,
     assign(socket,
       page_title: "Help Articles — Admin",
       active_nav: :admin_help,
       articles: articles,
       categories: categories,
       filter: :all
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
            Help Articles
          </h1>
          <p class="text-on-surface-variant mt-2">
            Manage help center content. Create, edit, publish, and organize articles.
          </p>
        </div>
        <a
          href="/admin/help/new"
          class="primary-gradient px-5 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95 flex items-center gap-2 whitespace-nowrap"
        >
          <span class="material-symbols-outlined text-lg">add</span> New Article
        </a>
      </div>

      <div class="flex gap-1 bg-surface-container rounded-lg p-1">
        <button
          :for={tab <- [:all, :draft, :published, :archived]}
          phx-click="filter"
          phx-value-status={tab}
          class={"px-4 py-2 rounded-md text-sm font-medium transition-colors #{if @filter == tab, do: "bg-primary text-on-primary shadow-sm", else: "text-on-surface-variant hover:text-on-surface hover:bg-surface-container-highest"}"}
        >
          {tab |> Atom.to_string() |> String.capitalize()}
          <span class="ml-1.5 text-xs opacity-70">
            ({count_by_status(@articles, tab)})
          </span>
        </button>
      </div>

      <div class="bg-surface-container rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Title
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Category
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Status
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Position
              </th>
              <th class="text-right px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={article <- filtered_articles(@articles, @filter)}
              class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
            >
              <td class="px-6 py-4">
                <div class="font-medium text-on-surface">{article.title}</div>
                <div class="text-xs text-on-surface-variant mt-0.5">/{article.slug}</div>
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {category_name(@categories, article.category_id)}
              </td>
              <td class="px-6 py-4">
                <.status_badge status={article.status} />
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {article.position}
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center justify-end gap-2">
                  <a
                    href={"/admin/help/#{article.id}/edit"}
                    class="text-xs px-3 py-1.5 rounded-md bg-surface-container-highest text-on-surface hover:bg-primary/10 hover:text-primary transition-colors"
                  >
                    Edit
                  </a>
                  <button
                    :if={article.status == :draft}
                    phx-click="publish"
                    phx-value-id={article.id}
                    class="text-xs px-3 py-1.5 rounded-md bg-green-50 text-green-700 hover:bg-green-100 transition-colors"
                  >
                    Publish
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={article.id}
                    data-confirm="Are you sure you want to delete this article? This cannot be undone."
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
          :if={filtered_articles(@articles, @filter) == []}
          class="px-6 py-16 text-center text-on-surface-variant"
        >
          <span class="material-symbols-outlined text-4xl opacity-30 block mb-2">help</span>
          <p>No articles found.</p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, filter: String.to_existing_atom(status))}
  end

  def handle_event("publish", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    article = Ash.get!(FounderPad.HelpCenter.Article, id, actor: user)

    article
    |> Ash.Changeset.for_update(:publish, %{}, actor: user)
    |> Ash.update!()

    {:noreply,
     socket
     |> put_flash(:info, "Article published successfully.")
     |> assign(articles: load_articles(user))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    article = Ash.get!(FounderPad.HelpCenter.Article, id, actor: user)

    article
    |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
    |> Ash.destroy!()

    {:noreply,
     socket
     |> put_flash(:info, "Article deleted.")
     |> assign(articles: load_articles(user))}
  end

  defp load_articles(user) do
    FounderPad.HelpCenter.Article
    |> Ash.Query.for_read(:read, %{}, actor: user)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: user)
  end

  defp load_categories(user) do
    FounderPad.HelpCenter.Category
    |> Ash.Query.for_read(:read, %{}, actor: user)
    |> Ash.Query.sort(position: :asc)
    |> Ash.read!(actor: user)
  end

  defp filtered_articles(articles, :all), do: articles
  defp filtered_articles(articles, status), do: Enum.filter(articles, &(&1.status == status))

  defp count_by_status(articles, :all), do: length(articles)
  defp count_by_status(articles, status), do: articles |> Enum.count(&(&1.status == status))

  defp category_name(categories, category_id) do
    case Enum.find(categories, &(&1.id == category_id)) do
      nil -> "—"
      cat -> cat.name
    end
  end

  defp status_badge(assigns) do
    {bg, text} =
      case assigns.status do
        :draft -> {"bg-neutral-100 text-neutral-600", "Draft"}
        :published -> {"bg-green-100 text-green-700", "Published"}
        :archived -> {"bg-amber-100 text-amber-700", "Archived"}
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
