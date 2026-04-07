defmodule FounderPadWeb.Blog.BlogIndexLive do
  use FounderPadWeb, :live_view

  import FounderPadWeb.BlogComponents

  @per_page 9

  def mount(_params, _session, socket) do
    posts =
      FounderPad.Content.Post
      |> Ash.Query.for_read(:published)
      |> Ash.Query.load([:author, :categories, :tags])
      |> Ash.Query.limit(@per_page)
      |> Ash.read!()

    categories =
      FounderPad.Content.Category
      |> Ash.read!()

    {:ok,
     assign(socket,
       page_title: "Blog — FounderPad",
       posts: posts,
       categories: categories
     ), layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary">
      <.blog_nav active="blog" />

      <header class="pt-20 bg-gradient-to-b from-primary/[0.03] to-transparent py-16 px-6">
        <div class="max-w-6xl mx-auto text-center">
          <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">Blog</p>
          <h1 class="font-heading text-4xl md:text-5xl font-extrabold tracking-tight text-on-surface mb-4">
            Insights & Updates
          </h1>
          <p class="text-on-surface-variant text-lg max-w-2xl mx-auto leading-relaxed">
            Insights, tutorials, and updates from the FounderPad team.
          </p>
        </div>
      </header>

      <div :if={@categories != []} class="max-w-6xl mx-auto px-6 mb-8">
        <div class="flex flex-wrap gap-2">
          <a
            href="/blog"
            class="px-4 py-1.5 rounded-full text-sm font-medium bg-primary text-on-primary"
          >
            All Posts
          </a>
          <a
            :for={cat <- @categories}
            href={"/blog/category/#{cat.slug}"}
            class="px-4 py-1.5 rounded-full text-sm font-medium bg-surface-container text-on-surface-variant hover:bg-primary/10 hover:text-primary transition-colors"
          >
            {cat.name}
          </a>
        </div>
      </div>

      <main class="max-w-6xl mx-auto px-6 pb-16">
        <div :if={@posts == []} class="text-center py-20 text-on-surface-variant">
          <span class="material-symbols-outlined text-5xl mb-4 block">article</span>
          <p class="text-lg">No posts yet. Check back soon!</p>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          <.blog_card :for={post <- @posts} post={post} />
        </div>
      </main>

      <.public_footer />
    </div>
    """
  end

  defp blog_nav(assigns) do
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
          <a
            href="/blog"
            class={"hover:text-on-surface transition-colors " <> if(@active == "blog", do: "text-primary", else: "")}
          >
            Blog
          </a>
          <a href="/docs" class="hover:text-on-surface transition-colors">Docs</a>
          <a href="/docs/changelog" class="hover:text-on-surface transition-colors">Changelog</a>
          <a href="/auth/login" class="hover:text-on-surface transition-colors">Login</a>
        </div>

        <div class="flex items-center gap-3">
          <a
            href="/auth/register"
            class="hidden sm:inline-flex items-center px-5 py-2 rounded-lg text-sm font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95"
          >
            Get Started
          </a>
          <button
            id="theme-toggle-blog"
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
