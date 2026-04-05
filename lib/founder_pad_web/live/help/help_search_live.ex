defmodule FounderPadWeb.Help.HelpSearchLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(params, _session, socket) do
    query = Map.get(params, "q", "")

    results =
      if query != "" do
        FounderPad.HelpCenter.Article
        |> Ash.Query.for_read(:search, %{query: query})
        |> Ash.Query.load([:category])
        |> Ash.read!()
      else
        []
      end

    {:ok,
     assign(socket,
       page_title: "Search Help — FounderPad",
       query: query,
       results: results
     ), layout: false}
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

          <h1 class="font-heading text-3xl font-extrabold tracking-tight text-on-surface mb-6">
            Search Results
          </h1>

          <form action="/help/search" method="get" class="max-w-xl">
            <div class="relative">
              <span class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-on-surface-variant/40 text-lg">
                search
              </span>
              <input
                type="text"
                name="q"
                value={@query}
                placeholder="Search help articles..."
                class="w-full bg-surface-container rounded-xl pl-12 pr-4 py-3.5 text-sm focus:ring-2 focus:ring-primary/30 text-on-surface placeholder:text-on-surface-variant/40 outline-none"
              />
            </div>
          </form>
        </div>
      </header>

      <main class="max-w-4xl mx-auto px-6 pb-16">
        <div :if={@query != ""} class="text-sm text-on-surface-variant mb-6">
          {length(@results)} {if length(@results) == 1, do: "result", else: "results"} for "{@query}"
        </div>

        <div :if={@results == [] && @query != ""} class="text-center py-16 text-on-surface-variant">
          <span class="material-symbols-outlined text-5xl mb-4 block">search_off</span>
          <p class="text-lg">No articles found matching your search.</p>
          <p class="text-sm mt-2">
            Try different keywords or <a href="/help/contact" class="text-primary hover:underline">contact support</a>.
          </p>
        </div>

        <div class="space-y-4">
          <a
            :for={article <- @results}
            href={"/help/#{article.category.slug}/#{article.slug}"}
            class="block bg-surface-container rounded-xl p-6 hover:bg-surface-container-highest transition-colors border border-outline-variant/10 hover:border-primary/20"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <h2 class="text-lg font-bold text-on-surface mb-1">{article.title}</h2>
                <p :if={article.excerpt} class="text-sm text-on-surface-variant leading-relaxed">
                  {article.excerpt}
                </p>
              </div>
              <span class="shrink-0 px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary/10 text-primary">
                {article.category.name}
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
            id="theme-toggle-help-search"
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
