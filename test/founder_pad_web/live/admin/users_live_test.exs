defmodule FounderPadWeb.Admin.UsersLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "admin users list" do
    test "admin can see user list", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)
      Factory.create_user!(%{email: "visible@example.com"})

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "Users"
      assert html =~ "visible@example.com"
    end

    test "non-admin is redirected", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      assert {:error, {:live_redirect, _}} = live(conn, ~p"/admin/users")
    end

    test "admin can suspend a user", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)
      target = Factory.create_user!(%{email: "target@example.com"})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view
      |> element(~s|button[phx-click=suspend][phx-value-id="#{target.id}"]|)
      |> render_click()

      html = render(view)
      assert html =~ "User suspended."

      reloaded = Ash.get!(FounderPad.Accounts.User, target.id)
      assert reloaded.suspended_at
    end

    test "admin can unsuspend a user", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)
      target = Factory.create_user!(%{email: "suspended@example.com"})

      target
      |> Ash.Changeset.for_update(:suspend, %{}, actor: admin)
      |> Ash.update!()

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view
      |> element(~s|button[phx-click=unsuspend][phx-value-id="#{target.id}"]|)
      |> render_click()

      html = render(view)
      assert html =~ "User unsuspended."

      reloaded = Ash.get!(FounderPad.Accounts.User, target.id)
      refute reloaded.suspended_at
    end

    test "admin can search users by email", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)
      Factory.create_user!(%{email: "findme@example.com"})
      Factory.create_user!(%{email: "hidden@example.com"})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      html =
        view
        |> element(~s|form[phx-change="search"]|)
        |> render_change(%{"query" => "findme"})

      assert html =~ "findme@example.com"
      refute html =~ "hidden@example.com"
    end
  end

  describe "admin user detail" do
    test "admin can view user detail", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)
      target = Factory.create_user!(%{email: "detail@example.com"})

      {:ok, _view, html} = live(conn, ~p"/admin/users/#{target.id}")

      assert html =~ "detail@example.com"
      assert html =~ "User Detail"
    end

    test "admin can suspend user from detail page", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)
      target = Factory.create_user!(%{email: "detail-suspend@example.com"})

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{target.id}")

      view
      |> element("button[phx-click=suspend]")
      |> render_click()

      html = render(view)
      assert html =~ "User suspended."
      assert html =~ "Suspended"
    end

    test "admin can toggle admin status", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)
      target = Factory.create_user!(%{email: "toggle@example.com"})

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{target.id}")

      view
      |> element("button[phx-click=toggle_admin]")
      |> render_click()

      html = render(view)
      assert html =~ "Admin status updated."

      reloaded = Ash.get!(FounderPad.Accounts.User, target.id)
      assert reloaded.is_admin
    end

    test "non-admin is redirected from user detail", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      target = Factory.create_user!()

      assert {:error, {:live_redirect, _}} = live(conn, ~p"/admin/users/#{target.id}")
    end
  end
end
