defmodule FounderPadWeb.Help.HelpIndexLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    categories =
      FounderPad.HelpCenter.Category
      |> Ash.Query.for_read(:read)
      |> Ash.Query.load([:articles])
      |> Ash.Query.sort(position: :asc)
      |> Ash.read!()

    {:ok,
     assign(socket,
       page_title: "Help Center — FounderPad",
       categories: categories
     ), layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary">
      <.help_nav active="help" />

      <header class="pt-20 bg-gradient-to-b from-primary/[0.03] to-transparent py-16 px-6">
        <div class="max-w-4xl mx-auto text-center">
          <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">
            Help Center
          </p>
          <h1 class="font-heading text-4xl md:text-5xl font-extrabold tracking-tight text-on-surface mb-4">
            How can we help?
          </h1>
          <p class="text-on-surface-variant text-lg max-w-2xl mx-auto leading-relaxed mb-8">
            Find answers, guides, and resources to help you get the most out of FounderPad.
          </p>

          <form action="/help/search" method="get" class="max-w-xl mx-auto">
            <div class="relative">
              <span class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-on-surface-variant/40 text-lg">
                search
              </span>
              <input
                type="text"
                name="q"
                placeholder="Search help articles..."
                class="w-full bg-surface-container rounded-xl pl-12 pr-4 py-3.5 text-sm focus:ring-2 focus:ring-primary/30 text-on-surface placeholder:text-on-surface-variant/40 outline-none"
              />
            </div>
          </form>
        </div>
      </header>

      <main class="max-w-6xl mx-auto px-6 pb-16">
        <div :if={@categories == []} class="text-center py-20 text-on-surface-variant">
          <span class="material-symbols-outlined text-5xl mb-4 block">help</span>
          <p class="text-lg">No help categories yet. Check back soon!</p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <a
            :for={cat <- @categories}
            href={"/help/#{cat.slug}"}
            class="group bg-surface-container rounded-xl p-6 hover:bg-surface-container-highest transition-colors border border-outline-variant/10 hover:border-primary/20"
          >
            <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center mb-4 group-hover:bg-primary/20 transition-colors">
              <span class="material-symbols-outlined text-primary text-2xl">
                {cat.icon || "help"}
              </span>
            </div>
            <h2 class="text-lg font-bold font-headline text-on-surface mb-2 group-hover:text-primary transition-colors">
              {cat.name}
            </h2>
            <p :if={cat.description} class="text-sm text-on-surface-variant leading-relaxed mb-3">
              {cat.description}
            </p>
            <p class="text-xs text-on-surface-variant/60">
              {length(cat.articles)} {if length(cat.articles) == 1, do: "article", else: "articles"}
            </p>
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
            id="theme-toggle-help"
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
