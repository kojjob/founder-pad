defmodule FounderPadWeb.SitemapController do
  use FounderPadWeb, :controller

  require Ash.Query

  def index(conn, _params) do
    host = FounderPadWeb.Endpoint.url()

    static_urls = [
      %{loc: host, changefreq: "weekly", priority: "1.0"},
      %{loc: "#{host}/auth/login", changefreq: "monthly", priority: "0.8"},
      %{loc: "#{host}/auth/register", changefreq: "monthly", priority: "0.8"},
      %{loc: "#{host}/blog", changefreq: "daily", priority: "0.9"},
      %{loc: "#{host}/changelog", changefreq: "weekly", priority: "0.7"},
      %{loc: "#{host}/docs", changefreq: "weekly", priority: "0.7"},
      %{loc: "#{host}/docs/api", changefreq: "weekly", priority: "0.6"}
    ]

    blog_urls =
      FounderPad.Content.Post
      |> Ash.Query.for_read(:published)
      |> Ash.read!()
      |> Enum.map(fn post ->
        %{loc: "#{host}/blog/#{post.slug}", changefreq: "weekly", priority: "0.7"}
      end)

    urls = static_urls ++ blog_urls

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, render_sitemap(urls))
  end

  defp render_sitemap(urls) do
    entries =
      Enum.map_join(urls, "\n", fn url ->
        """
        <url>
          <loc>#{url.loc}</loc>
          <changefreq>#{url.changefreq}</changefreq>
          <priority>#{url.priority}</priority>
        </url>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{entries}
    </urlset>
    """
  end
end
