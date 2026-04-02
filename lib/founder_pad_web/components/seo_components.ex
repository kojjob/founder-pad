defmodule FounderPadWeb.SeoComponents do
  @moduledoc "Function components for SEO meta tags and structured data."
  use Phoenix.Component

  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :image, :string, default: nil
  attr :url, :string, default: nil
  attr :type, :string, default: "website"

  def og_meta(assigns) do
    ~H"""
    <meta :if={@title} property="og:title" content={@title} />
    <meta :if={@description} property="og:description" content={@description} />
    <meta :if={@image} property="og:image" content={@image} />
    <meta :if={@url} property="og:url" content={@url} />
    <meta property="og:type" content={@type} />
    <meta :if={@title} name="twitter:card" content="summary_large_image" />
    <meta :if={@title} name="twitter:title" content={@title} />
    <meta :if={@description} name="twitter:description" content={@description} />
    <meta :if={@image} name="twitter:image" content={@image} />
    """
  end

  attr :post, :map, required: true
  attr :author, :map, required: true
  attr :site_url, :string, required: true

  def article_json_ld(assigns) do
    json =
      Jason.encode!(%{
        "@context" => "https://schema.org",
        "@type" => "Article",
        "headline" => assigns.post.meta_title || assigns.post.title,
        "description" => assigns.post.meta_description || assigns.post.excerpt,
        "image" => assigns.post.og_image_url || assigns.post.featured_image_url,
        "author" => %{"@type" => "Person", "name" => assigns.author.name || assigns.author.email},
        "datePublished" => to_string(assigns.post.published_at),
        "dateModified" => to_string(assigns.post.updated_at),
        "publisher" => %{
          "@type" => "Organization",
          "name" => "FounderPad"
        }
      })

    assigns = assign(assigns, :json, json)

    ~H"""
    <script type="application/ld+json">
      {raw(@json)}
    </script>
    """
  end

  attr :url, :string, required: true

  def canonical(assigns) do
    ~H"""
    <link rel="canonical" href={@url} />
    """
  end
end
