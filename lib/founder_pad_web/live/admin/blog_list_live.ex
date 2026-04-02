defmodule FounderPadWeb.Admin.BlogListLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  import FounderPadWeb.BlogComponents, only: [seo_score_badge: 1]

  alias FounderPad.Content.SeoScorer

  def mount(_params, _session, socket) do
    posts = load_posts(socket.assigns.current_user)

    {:ok,
     assign(socket,
       page_title: "Blog \u2014 Admin",
       active_nav: :admin_blog,
       posts: posts,
       filter: :all
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <%!-- Header --%>
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
            Blog Posts
          </h1>
          <p class="text-on-surface-variant mt-2">
            Manage your blog content. Create, edit, publish, and archive posts.
          </p>
        </div>
        <a
          href="/admin/blog/new"
          class="primary-gradient px-5 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95 flex items-center gap-2 whitespace-nowrap"
        >
          <span class="material-symbols-outlined text-lg">add</span> New Post
        </a>
      </div>

      <%!-- Status Filter Tabs --%>
      <div class="flex gap-1 bg-surface-container rounded-lg p-1">
        <button
          :for={tab <- [:all, :draft, :published, :scheduled, :archived]}
          phx-click="filter"
          phx-value-status={tab}
          class={"px-4 py-2 rounded-md text-sm font-medium transition-colors #{if @filter == tab, do: "bg-primary text-on-primary shadow-sm", else: "text-on-surface-variant hover:text-on-surface hover:bg-surface-container-highest"}"}
        >
          {tab |> Atom.to_string() |> String.capitalize()}
          <span class="ml-1.5 text-xs opacity-70">
            ({count_by_status(@posts, tab)})
          </span>
        </button>
      </div>

      <%!-- Posts Table --%>
      <div class="bg-surface-container rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Title
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Status
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Author
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Published
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                SEO
              </th>
              <th class="text-right px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={post <- filtered_posts(@posts, @filter)}
              class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
            >
              <td class="px-6 py-4">
                <div class="font-medium text-on-surface">{post.title}</div>
                <div class="text-xs text-on-surface-variant mt-0.5">/{post.slug}</div>
              </td>
              <td class="px-6 py-4">
                <.status_badge status={post.status} />
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {if post.author, do: post.author.name || post.author.email, else: "—"}
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {if post.published_at,
                  do: Calendar.strftime(post.published_at, "%b %d, %Y"),
                  else: "—"}
              </td>
              <td class="px-6 py-4">
                <.seo_score_badge score={SeoScorer.score(post).score} />
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center justify-end gap-2">
                  <a
                    href={"/admin/blog/#{post.id}/edit"}
                    class="text-xs px-3 py-1.5 rounded-md bg-surface-container-highest text-on-surface hover:bg-primary/10 hover:text-primary transition-colors"
                  >
                    Edit
                  </a>
                  <button
                    :if={post.status == :draft}
                    phx-click="publish"
                    phx-value-id={post.id}
                    class="text-xs px-3 py-1.5 rounded-md bg-green-50 text-green-700 hover:bg-green-100 transition-colors"
                  >
                    Publish
                  </button>
                  <button
                    :if={post.status in [:published, :draft]}
                    phx-click="archive"
                    phx-value-id={post.id}
                    class="text-xs px-3 py-1.5 rounded-md bg-amber-50 text-amber-700 hover:bg-amber-100 transition-colors"
                  >
                    Archive
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={post.id}
                    data-confirm="Are you sure you want to delete this post? This cannot be undone."
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
          :if={filtered_posts(@posts, @filter) == []}
          class="px-6 py-16 text-center text-on-surface-variant"
        >
          <span class="material-symbols-outlined text-4xl opacity-30 block mb-2">article</span>
          <p>No posts found.</p>
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

    post = Ash.get!(FounderPad.Content.Post, id, actor: user)

    post
    |> Ash.Changeset.for_update(:publish, %{}, actor: user)
    |> Ash.update!()

    {:noreply,
     socket
     |> put_flash(:info, "Post published successfully.")
     |> assign(posts: load_posts(user))}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    post = Ash.get!(FounderPad.Content.Post, id, actor: user)

    post
    |> Ash.Changeset.for_update(:archive, %{}, actor: user)
    |> Ash.update!()

    {:noreply,
     socket
     |> put_flash(:info, "Post archived.")
     |> assign(posts: load_posts(user))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    post = Ash.get!(FounderPad.Content.Post, id, actor: user)

    post
    |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
    |> Ash.destroy!()

    {:noreply,
     socket
     |> put_flash(:info, "Post deleted.")
     |> assign(posts: load_posts(user))}
  end

  defp load_posts(user) do
    FounderPad.Content.Post
    |> Ash.Query.for_read(:read, %{}, actor: user)
    |> Ash.Query.load([:author, :categories])
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: user)
  end

  defp filtered_posts(posts, :all), do: posts
  defp filtered_posts(posts, status), do: Enum.filter(posts, &(&1.status == status))

  defp count_by_status(posts, :all), do: length(posts)
  defp count_by_status(posts, status), do: posts |> Enum.count(&(&1.status == status))

  defp status_badge(assigns) do
    {bg, text} =
      case assigns.status do
        :draft -> {"bg-neutral-100 text-neutral-600", "Draft"}
        :published -> {"bg-green-100 text-green-700", "Published"}
        :scheduled -> {"bg-blue-100 text-blue-700", "Scheduled"}
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
