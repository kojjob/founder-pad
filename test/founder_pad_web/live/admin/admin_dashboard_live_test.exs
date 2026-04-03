defmodule FounderPadWeb.Admin.AdminDashboardLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  describe "admin dashboard" do
    test "admin can see dashboard with stats", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, _view, html} = live(conn, ~p"/admin")

      assert html =~ "Admin Dashboard"
      assert html =~ "Users"
      assert html =~ "Organisations"
      assert html =~ "Active API Keys"
      assert html =~ "Feature Flags"
    end

    test "non-admin is redirected", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      assert {:error, {:live_redirect, _}} = live(conn, ~p"/admin")
    end
  end
end
