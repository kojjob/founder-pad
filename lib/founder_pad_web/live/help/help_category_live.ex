defmodule FounderPadWeb.Help.HelpCategoryLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(%{"category_slug" => slug}, _session, socket) do
    category =
      FounderPad.HelpCenter.Category
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(slug == ^slug)
      |> Ash.read_one!()

    case category do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Category not found.")
         |> push_navigate(to: "/help"), layout: false}

      category ->
        articles =
          FounderPad.HelpCenter.Article
          |> Ash.Query.for_read(:by_category, %{category_id: category.id})
          |> Ash.read!()

        {:ok,
         assign(socket,
           page_title: "#{category.name} — Help Center — FounderPad",
           category: category,
           articles: articles
         ), layout: false}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary">
      <.help_nav active="help" />

      <header class="pt-20 bg-gradient-to-b from-primary/[0.03] to-transparent py-12 px-6">
        <div class="max-w-4xl mx-auto">
          <a
            href="/help"
            class="text-sm text-on-surface-variant hover:text-primary transition-colors flex items-center gap-1 mb-4"
          >
            <span class="material-symbols-outlined text-sm">arrow_back</span> Back to Help Center
          </a>

          <div class="flex items-center gap-4 mb-4">
            <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
              <span class="material-symbols-outlined text-primary text-2xl">
                {@category.icon || "help"}
              </span>
            </div>
            <div>
              <h1 class="font-heading text-3xl font-extrabold tracking-tight text-on-surface">
                {@category.name}
              </h1>
              <p :if={@category.description} class="text-on-surface-variant mt-1">
                {@category.description}
              </p>
            </div>
          </div>
        </div>
      </header>

      <main class="max-w-4xl mx-auto px-6 pb-16">
        <div :if={@articles == []} class="text-center py-16 text-on-surface-variant">
          <span class="material-symbols-outlined text-5xl mb-4 block">article</span>
          <p class="text-lg">No articles in this category yet.</p>
        </div>

        <div class="space-y-3">
          <a
            :for={article <- @articles}
            href={"/help/#{@category.slug}/#{article.slug}"}
            class="block bg-surface-container rounded-xl p-5 hover:bg-surface-container-highest transition-colors border border-outline-variant/10 hover:border-primary/20 group"
          >
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-base font-semibold text-on-surface group-hover:text-primary transition-colors">
                  {article.title}
                </h2>
                <p :if={article.excerpt} class="text-sm text-on-surface-variant mt-1 leading-relaxed">
                  {article.excerpt}
                </p>
              </div>
              <span class="material-symbols-outlined text-on-surface-variant/40 group-hover:text-primary transition-colors">
                chevron_right
              </span>
            </div>
          </a>
        </div>
      </main>

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
            id="theme-toggle-help-category"
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
