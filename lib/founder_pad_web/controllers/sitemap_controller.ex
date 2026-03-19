defmodule FounderPadWeb.SitemapController do
  use FounderPadWeb, :controller

  def index(conn, _params) do
    host = FounderPadWeb.Endpoint.url()

    urls = [
      %{loc: host, changefreq: "weekly", priority: "1.0"},
      %{loc: "#{host}/auth/login", changefreq: "monthly", priority: "0.8"},
      %{loc: "#{host}/auth/register", changefreq: "monthly", priority: "0.8"}
    ]

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
