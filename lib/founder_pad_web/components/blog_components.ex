defmodule FounderPadWeb.BlogComponents do
  @moduledoc "Reusable function components for blog UI."
  use Phoenix.Component

  attr :post, :map, required: true

  def blog_card(assigns) do
    ~H"""
    <article class="group bg-white rounded-2xl border border-neutral-200/60 overflow-hidden hover:shadow-lg transition-all duration-300">
      <a href={"/blog/#{@post.slug}"} class="block">
        <div :if={@post.featured_image_url} class="aspect-[16/9] overflow-hidden">
          <img
            src={@post.featured_image_url}
            alt={@post.title}
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
          />
        </div>
        <div :if={!@post.featured_image_url} class="aspect-[16/9] bg-gradient-to-br from-primary/5 to-primary/10 flex items-center justify-center">
          <span class="material-symbols-outlined text-4xl text-primary/30">article</span>
        </div>
        <div class="p-6">
          <div class="flex items-center gap-2 mb-3">
            <.category_badge :for={cat <- (@post.categories || [])} category={cat} />
          </div>
          <h3 class="font-heading text-lg font-semibold text-on-surface mb-2 group-hover:text-primary transition-colors">
            {@post.title}
          </h3>
          <p :if={@post.excerpt} class="text-on-surface-variant text-sm line-clamp-2 mb-4">
            {@post.excerpt}
          </p>
          <.post_meta post={@post} />
        </div>
      </a>
    </article>
    """
  end

  attr :post, :map, required: true

  def post_meta(assigns) do
    ~H"""
    <div class="flex items-center gap-3 text-xs text-on-surface-variant">
      <span :if={@post.author} class="flex items-center gap-1.5">
        <span class="material-symbols-outlined text-sm">person</span>
        {@post.author.name || @post.author.email}
      </span>
      <span :if={@post.published_at} class="flex items-center gap-1.5">
        <span class="material-symbols-outlined text-sm">calendar_today</span>
        {Calendar.strftime(@post.published_at, "%b %d, %Y")}
      </span>
      <span class="flex items-center gap-1.5">
        <span class="material-symbols-outlined text-sm">schedule</span>
        {@post.reading_time_minutes} min read
      </span>
    </div>
    """
  end

  attr :category, :map, required: true

  def category_badge(assigns) do
    ~H"""
    <a
      href={"/blog/category/#{@category.slug}"}
      class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary/10 text-primary hover:bg-primary/20 transition-colors"
    >
      {@category.name}
    </a>
    """
  end

  attr :tag, :map, required: true

  def tag_badge(assigns) do
    ~H"""
    <a
      href={"/blog/tag/#{@tag.slug}"}
      class="inline-flex items-center px-2 py-0.5 rounded-md text-xs text-on-surface-variant border border-neutral-200 hover:border-primary hover:text-primary transition-colors"
    >
      {@tag.name}
    </a>
    """
  end

  attr :score, :integer, required: true

  def seo_score_badge(assigns) do
    color =
      cond do
        assigns.score >= 80 -> "bg-green-100 text-green-700"
        assigns.score >= 50 -> "bg-amber-100 text-amber-700"
        true -> "bg-red-100 text-red-700"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{@color}"}>
      SEO: {@score}%
    </span>
    """
  end
end
