defmodule FounderPadWeb.TeamLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "team page rendering" do
    test "renders the team page with member list", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/team")

      assert html =~ "Organization Members"
      assert html =~ "Invite New Member"
      assert html =~ "Total Seats"
    end
  end

  describe "invite modal" do
    test "opens invite modal when clicking Invite New Member", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, html} = live(conn, ~p"/team")

      refute html =~ "Invite Team Member"

      html = view |> element("button", "Invite New Member") |> render_click()

      assert html =~ "Invite Team Member"
      assert html =~ "invite-form"
    end

    test "closes invite modal", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/team")

      view |> element("button", "Invite New Member") |> render_click()
      html = view |> element("button[phx-click=close_invite_modal]") |> render_click()

      refute html =~ "Invite Team Member"
    end

    test "inviting a valid user creates membership", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      invitee = Factory.create_user!(%{email: "invitee@example.com"})

      {:ok, view, _html} = live(conn, ~p"/team")

      view |> element("button", "Invite New Member") |> render_click()

      html =
        view
        |> form("#invite-form", %{"email" => invitee.email, "role" => "member"})
        |> render_submit()

      assert html =~ "added to team"
      refute html =~ "Invite Team Member"
    end

    test "inviting a nonexistent email shows error", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/team")

      view |> element("button", "Invite New Member") |> render_click()

      html =
        view
        |> form("#invite-form", %{"email" => "nobody@nowhere.com", "role" => "member"})
        |> render_submit()

      assert html =~ "No user found with that email"
    end
  end

  describe "delete member" do
    test "removing a member updates the list", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      member_user = Factory.create_user!(%{email: "removeme@example.com"})
      membership = Factory.create_membership!(member_user, org, :member)

      {:ok, view, html} = live(conn, ~p"/team")

      assert html =~ "removeme@example.com"

      view
      |> element(~s|button[phx-click=delete_member][phx-value-id="#{membership.id}"]|)
      |> render_click()

      html = render(view)
      assert html =~ "Member removed"
    end
  end
end
