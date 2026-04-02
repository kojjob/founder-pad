defmodule FounderPadWeb.FeedController do
  use FounderPadWeb, :controller

  require Ash.Query

  def blog_feed(conn, _params) do
    posts =
      FounderPad.Content.Post
      |> Ash.Query.for_read(:published)
      |> Ash.Query.load([:author])
      |> Ash.Query.limit(20)
      |> Ash.read!()

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, render_rss("FounderPad Blog", "/blog", posts, :blog))
  end

  def changelog_feed(conn, _params) do
    entries =
      FounderPad.Content.ChangelogEntry
      |> Ash.Query.for_read(:published)
      |> Ash.Query.limit(20)
      |> Ash.read!()

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, render_rss("FounderPad Changelog", "/changelog", entries, :changelog))
  end

  defp render_rss(title, path, items, type) do
    host = FounderPadWeb.Endpoint.url()

    items_xml =
      Enum.map_join(items, "\n", fn item ->
        case type do
          :blog ->
            """
            <item>
              <title><![CDATA[#{item.title}]]></title>
              <link>#{host}/blog/#{item.slug}</link>
              <description><![CDATA[#{item.excerpt || ""}]]></description>
              <pubDate>#{format_rfc822(item.published_at)}</pubDate>
              <guid>#{host}/blog/#{item.slug}</guid>
            </item>
            """

          :changelog ->
            """
            <item>
              <title><![CDATA[#{item.version}: #{item.title}]]></title>
              <link>#{host}/changelog</link>
              <description><![CDATA[#{item.body || ""}]]></description>
              <pubDate>#{format_rfc822(item.published_at)}</pubDate>
              <guid>#{host}/changelog/#{item.id}</guid>
            </item>
            """
        end
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
      <channel>
        <title>#{title}</title>
        <link>#{host}#{path}</link>
        <description>#{title} feed</description>
        <atom:link href="#{host}#{path}/feed.xml" rel="self" type="application/rss+xml"/>
        #{items_xml}
      </channel>
    </rss>
    """
  end

  defp format_rfc822(nil), do: ""

  defp format_rfc822(datetime) do
    Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S +0000")
  end
end
