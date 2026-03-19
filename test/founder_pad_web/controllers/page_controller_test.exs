defmodule FounderPadWeb.LandingPageTest do
  use FounderPadWeb.ConnCase

  test "GET / renders landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Ship Your SaaS"
  end

  test "GET / includes SEO meta tags", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "og:title"
    assert html =~ "twitter:card"
    assert html =~ "FounderPad"
  end

  test "GET /sitemap.xml returns XML", %{conn: conn} do
    conn = get(conn, ~p"/sitemap.xml")
    assert response_content_type(conn, :xml)
    assert conn.resp_body =~ "urlset"
  end
end
