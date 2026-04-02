defmodule FounderPadWeb.Admin.BlogListLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  defp setup_authenticated_admin(conn) do
    admin = Factory.create_admin_user!()
    org = Factory.create_organisation!()
    Factory.create_membership!(admin, org, :owner)

    token = AshAuthentication.user_to_subject(admin)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, admin, org}
  end

  describe "admin blog list" do
    test "admin can see all posts including drafts", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      Factory.create_post!(%{title: "Draft Post", status: :draft, actor: admin})
      Factory.create_published_post!(%{title: "Published Post", actor: admin})

      {:ok, _view, html} = live(conn, ~p"/admin/blog")

      assert html =~ "Blog Posts"
      assert html =~ "Draft Post"
      assert html =~ "Published Post"
    end

    test "non-admin is redirected", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      assert {:error, {:live_redirect, _}} = live(conn, ~p"/admin/blog")
    end

    test "can publish a draft post", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      _post = Factory.create_post!(%{title: "My Draft", status: :draft, actor: admin})

      {:ok, view, html} = live(conn, ~p"/admin/blog")

      assert html =~ "My Draft"
      assert html =~ "Draft"

      view
      |> element("button[phx-click=publish]")
      |> render_click()

      html = render(view)
      assert html =~ "Published"
      assert html =~ "Post published successfully."
    end

    test "can delete a post", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      Factory.create_post!(%{title: "To Delete", status: :draft, actor: admin})

      {:ok, view, html} = live(conn, ~p"/admin/blog")

      assert html =~ "To Delete"

      view
      |> element("button[phx-click=delete]")
      |> render_click()

      html = render(view)
      refute html =~ "To Delete"
      assert html =~ "Post deleted."
    end

    test "can filter posts by status", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      Factory.create_post!(%{title: "A Draft One", status: :draft, actor: admin})
      Factory.create_published_post!(%{title: "A Published One", actor: admin})

      {:ok, view, _html} = live(conn, ~p"/admin/blog")

      # Filter to draft only
      html =
        view
        |> element("button[phx-value-status=draft]")
        |> render_click()

      assert html =~ "A Draft One"
      refute html =~ "A Published One"

      # Filter to published only
      html =
        view
        |> element("button[phx-value-status=published]")
        |> render_click()

      refute html =~ "A Draft One"
      assert html =~ "A Published One"
    end

    test "can archive a post", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      _post = Factory.create_post!(%{title: "Archive Me", status: :draft, actor: admin})

      {:ok, view, _html} = live(conn, ~p"/admin/blog")

      view
      |> element("button[phx-click=archive]")
      |> render_click()

      html = render(view)
      assert html =~ "Archived"
      assert html =~ "Post archived."
    end

    test "shows new post link", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, _view, html} = live(conn, ~p"/admin/blog")

      assert html =~ "New Post"
      assert html =~ "/admin/blog/new"
    end
  end
end
