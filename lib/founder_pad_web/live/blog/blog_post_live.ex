defmodule FounderPadWeb.Blog.BlogPostLive do
  use FounderPadWeb, :live_view

  import FounderPadWeb.BlogComponents
  import FounderPadWeb.SeoComponents

  require Ash.Query

  def mount(%{"slug" => slug}, _session, socket) do
    case FounderPad.Content.Post
         |> Ash.Query.for_read(:by_slug, %{slug: slug})
         |> Ash.read_one() do
      {:ok, nil} ->
        {:ok, push_navigate(socket, to: "/blog"), layout: false}

      {:ok, post} ->
        site_url = FounderPadWeb.Endpoint.url()

        post_id = post.id

        related =
          FounderPad.Content.Post
          |> Ash.Query.for_read(:published)
          |> Ash.Query.load([:author, :categories])
          |> Ash.Query.filter(id != ^post_id)
          |> Ash.Query.limit(3)
          |> Ash.read!()

        {:ok,
         assign(socket,
           page_title: "#{post.title} — FounderPad Blog",
           page_description: post.meta_description || post.excerpt,
           post: post,
           related_posts: related,
           site_url: site_url
         ), layout: false}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary">
      <.blog_nav />

      <article class="pt-20">
        <header class="max-w-3xl mx-auto px-6 py-16">
          <div class="flex items-center gap-2 mb-4">
            <.category_badge :for={cat <- @post.categories || []} category={cat} />
          </div>
          <h1 class="font-heading text-3xl md:text-4xl lg:text-5xl font-extrabold tracking-tight text-on-surface mb-6">
            {@post.title}
          </h1>
          <.post_meta post={@post} />
        </header>

        <div :if={@post.featured_image_url} class="max-w-4xl mx-auto px-6 mb-12">
          <img
            src={@post.featured_image_url}
            alt={@post.title}
            class="w-full rounded-2xl object-cover"
          />
        </div>

        <div class="max-w-3xl mx-auto px-6 pb-16">
          <div class="prose prose-lg max-w-none
            prose-headings:font-heading prose-headings:font-bold prose-headings:text-on-surface
            prose-p:text-on-surface-variant prose-p:leading-relaxed
            prose-a:text-primary prose-a:no-underline hover:prose-a:underline
            prose-code:font-mono prose-code:text-primary
            prose-blockquote:border-primary prose-blockquote:text-on-surface-variant">
            {raw(@post.body)}
          </div>

          <div :if={(@post.tags || []) != []} class="mt-12 pt-8 border-t border-outline-variant/10">
            <h3 class="text-sm font-semibold text-on-surface-variant uppercase tracking-wider mb-3">
              Tags
            </h3>
            <div class="flex flex-wrap gap-2">
              <.tag_badge :for={tag <- @post.tags} tag={tag} />
            </div>
          </div>
        </div>
      </article>

      <div :if={@related_posts != []} class="max-w-6xl mx-auto px-6 pb-16">
        <h2 class="font-heading text-2xl font-bold text-on-surface mb-8">Related Posts</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
          <.blog_card :for={post <- @related_posts} post={post} />
        </div>
      </div>

      <.article_json_ld
        :if={@post.author}
        post={@post}
        author={@post.author}
        site_url={@site_url}
      />

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
          <a href="/blog" class="hover:text-on-surface transition-colors text-primary">Blog</a>
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
            id="theme-toggle-blog-post"
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
