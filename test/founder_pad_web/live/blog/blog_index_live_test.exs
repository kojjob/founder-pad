defmodule FounderPadWeb.Blog.BlogIndexLiveTest do
  use FounderPadWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FounderPad.Factory

  test "shows published posts", %{conn: conn} do
    admin = create_admin_user!()
    _published = create_published_post!(%{title: "Published Post", actor: admin})
    _draft = create_post!(%{title: "Draft Post", actor: admin})

    {:ok, _view, html} = live(conn, ~p"/blog")

    assert html =~ "Published Post"
    refute html =~ "Draft Post"
  end

  test "shows empty state when no posts", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/blog")
    assert html =~ "No posts yet"
  end

  test "displays categories as filter pills", %{conn: conn} do
    admin = create_admin_user!()
    _category = create_category!(%{name: "Engineering", actor: admin})

    {:ok, _view, html} = live(conn, ~p"/blog")

    assert html =~ "Engineering"
    assert html =~ "All Posts"
  end

  test "renders page title", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/blog")
    assert html =~ "Blog"
    assert html =~ "Insights"
  end
end
