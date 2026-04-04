defmodule FounderPadWeb.SearchControllerTest do
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  describe "GET /api/search" do
    test "returns page results for matching query", %{conn: conn} do
      conn = get(conn, "/api/search?q=dashboard")
      body = json_response(conn, 200)

      assert is_list(body["results"])
      assert Enum.any?(body["results"], fn r -> r["title"] == "Dashboard" end)
    end

    test "returns multiple page matches", %{conn: conn} do
      conn = get(conn, "/api/search?q=a")
      short_query = json_response(conn, 200)
      # Query too short (< 2 chars), should return empty
      assert short_query["results"] == []

      conn = get(conn, "/api/search?q=ag")
      body = json_response(conn, 200)
      assert Enum.any?(body["results"], fn r -> r["title"] == "Agents" end)
    end

    test "returns empty results for short query (less than 2 chars)", %{conn: conn} do
      conn = get(conn, "/api/search?q=a")
      body = json_response(conn, 200)
      assert body["results"] == []
    end

    test "returns empty results when no q param", %{conn: conn} do
      conn = get(conn, "/api/search")
      body = json_response(conn, 200)
      assert body["results"] == []
    end

    test "page results include type, title, url, and icon", %{conn: conn} do
      conn = get(conn, "/api/search?q=settings")
      body = json_response(conn, 200)

      result = Enum.find(body["results"], fn r -> r["title"] == "Settings" end)
      assert result
      assert result["type"] == "page"
      assert result["url"] == "/settings"
      assert result["icon"] == "settings"
    end

    test "search is case-insensitive for pages", %{conn: conn} do
      conn = get(conn, "/api/search?q=DASHBOARD")
      body = json_response(conn, 200)

      assert Enum.any?(body["results"], fn r -> r["title"] == "Dashboard" end)
    end

    test "returns blog post results for matching query", %{conn: conn} do
      admin = create_admin_user!()
      create_published_post!(%{title: "Getting Started Guide", actor: admin})

      conn = get(conn, "/api/search?q=getting+started")
      body = json_response(conn, 200)

      assert Enum.any?(body["results"], fn r ->
        r["title"] == "Getting Started Guide" && r["type"] == "blog"
      end)
    end

    test "does not return draft blog posts", %{conn: conn} do
      admin = create_admin_user!()
      create_post!(%{title: "Draft Secret Post", status: :draft, actor: admin})

      conn = get(conn, "/api/search?q=draft+secret")
      body = json_response(conn, 200)

      refute Enum.any?(body["results"], fn r -> r["title"] == "Draft Secret Post" end)
    end

    test "returns help article results for matching query", %{conn: conn} do
      admin = create_admin_user!()
      category = create_help_category!(%{actor: admin})
      create_published_help_article!(category, %{title: "How to Reset Password", actor: admin})

      conn = get(conn, "/api/search?q=reset+password")
      body = json_response(conn, 200)

      assert Enum.any?(body["results"], fn r ->
        r["title"] == "How to Reset Password" && r["type"] == "help"
      end)
    end

    test "results are grouped by type in order: page, blog, help", %{conn: conn} do
      admin = create_admin_user!()
      create_published_post!(%{title: "Dashboard Tips Blog", actor: admin})

      conn = get(conn, "/api/search?q=dashboard")
      body = json_response(conn, 200)

      types = body["results"] |> Enum.map(& &1["type"]) |> Enum.uniq()
      # Pages should come before blog
      page_idx = Enum.find_index(types, &(&1 == "page"))
      blog_idx = Enum.find_index(types, &(&1 == "blog"))

      if page_idx && blog_idx do
        assert page_idx < blog_idx
      end
    end
  end
end
