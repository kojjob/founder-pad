defmodule FounderPadWeb.ReferralsLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  describe "referrals page" do
    test "renders referrals page", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/referrals")

      assert html =~ "Referrals"
      assert html =~ "Invite others and earn rewards"
    end

    test "shows generate code button when no referral exists", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/referrals")

      assert html =~ "Generate Referral Code"
    end

    test "generates referral code on click", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/referrals")

      html = view |> element("button", "Generate Referral Code") |> render_click()

      assert html =~ "FP-"
    end

    test "shows referral code when one exists", %{conn: conn} do
      {conn, user, _org} = setup_authenticated_user(conn)

      # Create a referral
      FounderPad.Referrals.Referral
      |> Ash.Changeset.for_create(:create, %{referrer_id: user.id})
      |> Ash.create!()

      {:ok, _view, html} = live(conn, ~p"/referrals")

      assert html =~ "FP-"
      assert html =~ "Copy Link"
    end

    test "shows referral stats", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/referrals")

      assert html =~ "Total Referrals"
      assert html =~ "Completed"
      assert html =~ "Total Earned"
    end
  end
end
