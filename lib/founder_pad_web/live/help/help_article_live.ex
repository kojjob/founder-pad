defmodule FounderPadWeb.Help.HelpArticleLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(%{"category_slug" => category_slug, "slug" => slug}, _session, socket) do
    category =
      FounderPad.HelpCenter.Category
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(slug == ^category_slug)
      |> Ash.read_one!()

    case category do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Category not found.")
         |> push_navigate(to: "/help"), layout: false}

      category ->
        article =
          FounderPad.HelpCenter.Article
          |> Ash.Query.for_read(:published)
          |> Ash.Query.filter(category_id == ^category.id and slug == ^slug)
          |> Ash.read_one!()

        case article do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, "Article not found.")
             |> push_navigate(to: "/help/#{category_slug}"), layout: false}

          article ->
            related =
              FounderPad.HelpCenter.Article
              |> Ash.Query.for_read(:by_category, %{category_id: category.id})
              |> Ash.Query.filter(id != ^article.id)
              |> Ash.Query.limit(5)
              |> Ash.read!()

            {:ok,
             assign(socket,
               page_title: "#{article.title} — Help Center — FounderPad",
               category: category,
               article: article,
               related_articles: related
             ), layout: false}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary">
      <.help_nav active="help" />

      <div class="pt-20 max-w-4xl mx-auto px-6 pb-16">
        <div class="mb-8">
          <div class="flex items-center gap-2 text-sm text-on-surface-variant mb-4">
            <a href="/help" class="hover:text-primary transition-colors">Help Center</a>
            <span class="material-symbols-outlined text-xs">chevron_right</span>
            <a href={"/help/#{@category.slug}"} class="hover:text-primary transition-colors">
              {@category.name}
            </a>
          </div>

          <h1 class="font-heading text-3xl md:text-4xl font-extrabold tracking-tight text-on-surface mb-4">
            {@article.title}
          </h1>

          <p :if={@article.excerpt} class="text-on-surface-variant text-lg leading-relaxed">
            {@article.excerpt}
          </p>
        </div>

        <article class="prose prose-lg max-w-none dark:prose-invert prose-headings:font-headline prose-headings:tracking-tight prose-a:text-primary">
          {Phoenix.HTML.raw(@article.body)}
        </article>

        <div :if={@related_articles != []} class="mt-16 pt-8 border-t border-outline-variant/20">
          <h2 class="text-xl font-bold font-headline text-on-surface mb-6">
            Related articles
          </h2>
          <div class="space-y-3">
            <a
              :for={related <- @related_articles}
              href={"/help/#{@category.slug}/#{related.slug}"}
              class="block bg-surface-container rounded-xl p-4 hover:bg-surface-container-highest transition-colors border border-outline-variant/10 hover:border-primary/20 group"
            >
              <div class="flex items-center justify-between">
                <h3 class="text-sm font-semibold text-on-surface group-hover:text-primary transition-colors">
                  {related.title}
                </h3>
                <span class="material-symbols-outlined text-on-surface-variant/40 group-hover:text-primary text-sm transition-colors">
                  chevron_right
                </span>
              </div>
            </a>
          </div>
        </div>
      </div>

      <.public_footer />
    </div>
    """
  end

  defp help_nav(assigns) do
    ~H"""
    <nav class="fixed top-0 inset-x-0 z-50 bg-background/60 backdrop-blur-md">
      <div class="max-w-7xl mx-auto flex items-center justify-between px-6 py-4">
        <a href="/" class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
            <span class="material-symbols-outlined text-on-primary text-lg">architecture</span>
          </div>
          <span class="text-xl font-extrabold font-headline tracking-tight text-on-surface">
            FounderPad
          </span>
        </a>

        <div class="hidden md:flex items-center gap-8 text-sm font-medium text-on-surface-variant">
          <a href="/blog" class="hover:text-on-surface transition-colors">Blog</a>
          <a href="/docs" class="hover:text-on-surface transition-colors">Docs</a>
          <a
            href="/help"
            class={"hover:text-on-surface transition-colors " <> if(@active == "help", do: "text-primary", else: "")}
          >
            Help
          </a>
          <a href="/auth/login" class="hover:text-on-surface transition-colors">Sign In</a>
        </div>

        <div class="flex items-center gap-3">
          <a
            href="/auth/register"
            class="hidden sm:inline-flex items-center px-5 py-2 rounded-lg text-sm font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95"
          >
            Get Started
          </a>
          <button
            id="theme-toggle-help-article"
            phx-hook="ThemeToggle"
            class="p-2 text-on-surface-variant hover:text-on-surface transition-colors cursor-pointer rounded-lg hover:bg-surface-container-high/50"
          >
            <span class="material-symbols-outlined text-xl">dark_mode</span>
          </button>
        </div>
      </div>
    </nav>
    """
  end
end
