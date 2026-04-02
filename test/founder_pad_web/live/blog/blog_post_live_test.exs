defmodule FounderPadWeb.Blog.BlogPostLiveTest do
  use FounderPadWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FounderPad.Factory

  test "renders published post", %{conn: conn} do
    admin = create_admin_user!()

    post =
      create_published_post!(%{
        title: "My Test Post",
        body: "<p>Hello from the blog</p>",
        actor: admin
      })

    {:ok, _view, html} = live(conn, ~p"/blog/#{post.slug}")
    assert html =~ "My Test Post"
    assert html =~ "Hello from the blog"
  end

  test "redirects for non-existent slug", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/blog"}}} = live(conn, ~p"/blog/non-existent-slug")
  end

  test "shows post author information", %{conn: conn} do
    admin = create_admin_user!()

    post =
      create_published_post!(%{
        title: "Author Test Post",
        actor: admin
      })

    {:ok, _view, html} = live(conn, ~p"/blog/#{post.slug}")
    assert html =~ to_string(admin.email)
  end

  test "shows related posts section", %{conn: conn} do
    admin = create_admin_user!()
    post = create_published_post!(%{title: "Main Post", actor: admin})
    _related = create_published_post!(%{title: "Related Post", actor: admin})

    {:ok, _view, html} = live(conn, ~p"/blog/#{post.slug}")
    assert html =~ "Related Posts"
    assert html =~ "Related Post"
  end
end
