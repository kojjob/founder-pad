defmodule FounderPadWeb.TeamLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  import FounderPad.Factory

  describe "Team page rendering" do
    test "renders team page with member list", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, _view, html} = live(conn, "/team")
      assert html =~ "Organization Members"
      assert html =~ "Invite Members"
      assert html =~ "Total Seats"
    end

    test "shows current user in member list", %{conn: conn} do
      {conn, user, _org} = setup_authenticated_user(conn)
      {:ok, _view, html} = live(conn, "/team")
      assert html =~ to_string(user.email)
    end
  end

  describe "Invite modal" do
    test "opens and closes", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, view, _html} = live(conn, "/team")

      html = render_click(view, "show_invite_modal")
      assert html =~ "Invite Team Members"
      assert html =~ "Add up to 10 people"

      html = render_click(view, "close_invite_modal")
      refute html =~ "Invite Team Members"
    end

    test "add and remove email chips", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, view, _html} = live(conn, "/team")

      render_click(view, "show_invite_modal")
      html = render_submit(view, "add_invite_email", %{"email" => "alice@example.com"})
      assert html =~ "alice@example.com"

      html = render_click(view, "remove_invite_email", %{"email" => "alice@example.com"})
      refute html =~ "alice@example.com"
    end

    test "role selector shows descriptions", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, view, _html} = live(conn, "/team")

      html = render_click(view, "show_invite_modal")
      assert html =~ "View &amp; use agents"
      assert html =~ "Manage agents &amp; team"
      assert html =~ "Full access &amp; billing"
    end

    test "invite existing user creates membership", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      _invitee = create_user!(email: "invitee@example.com")

      {:ok, view, _html} = live(conn, "/team")
      render_click(view, "show_invite_modal")
      render_submit(view, "add_invite_email", %{"email" => "invitee@example.com"})
      render_click(view, "send_invites")

      assert render(view) =~ "added to team"
    end

    test "invite nonexistent email shows error", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, view, _html} = live(conn, "/team")

      render_click(view, "show_invite_modal")
      render_submit(view, "add_invite_email", %{"email" => "nobody@nowhere.com"})
      html = render_click(view, "send_invites")
      assert html =~ "no account found"
    end

    test "shows seat availability", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, view, _html} = live(conn, "/team")
      html = render_click(view, "show_invite_modal")
      assert html =~ "seat(s) available"
    end
  end

  describe "Member actions" do
    test "delete member shows success flash", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      member = create_user!(email: "removeme@example.com")
      membership = create_membership!(member, org, :member)

      {:ok, view, _html} = live(conn, "/team")

      render_click(view, "delete_member", %{"id" => membership.id})
      assert render(view) =~ "Member removed"
    end

    test "role edit inline dropdown", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      member = create_user!()
      membership = create_membership!(member, org, :member)

      {:ok, view, _html} = live(conn, "/team")
      html = render_click(view, "start_role_edit", %{"id" => membership.id})
      assert html =~ "select"

      render_submit(view, "change_role", %{"id" => membership.id, "role" => "admin"})
      html = render(view)
      assert html =~ "Admin"
    end

    test "manage seats modal opens from owner row", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, view, _html} = live(conn, "/team")

      html = render_click(view, "show_seats_modal")
      assert html =~ "Manage Seats"
      assert html =~ "Current Plan"
      assert html =~ "Billing page"
    end
  end

  describe "Search and pagination" do
    test "live search filters members", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      member = create_user!(email: "findme@test.com")
      create_membership!(member, org, :member)

      {:ok, view, _html} = live(conn, "/team")
      html = render_keyup(view, "live_search", %{"value" => "findme"})
      assert html =~ "findme@test.com"

      html = render_keyup(view, "live_search", %{"value" => "zzzznotfound"})
      assert html =~ "No members matching"
    end

    test "pagination prev/next buttons work", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      for i <- 1..8 do
        u = create_user!(email: "pager-#{i}@example.com")
        create_membership!(u, org, :member)
      end

      {:ok, view, _html} = live(conn, "/team")
      html = render_click(view, "next_page")
      assert html =~ "Showing"

      html = render_click(view, "prev_page")
      assert html =~ "Showing"
    end
  end
end
