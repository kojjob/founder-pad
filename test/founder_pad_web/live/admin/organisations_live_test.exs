defmodule FounderPadWeb.Admin.OrganisationsLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  describe "admin organisations list" do
    test "admin can see organisation list", %{conn: conn} do
      {conn, _admin, org} = setup_authenticated_admin(conn)

      {:ok, _view, html} = live(conn, ~p"/admin/organisations")

      assert html =~ "Organisations"
      assert html =~ org.name
    end

    test "shows member count for each organisation", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, _view, html} = live(conn, ~p"/admin/organisations")

      # The admin's org should have at least 1 member (the admin)
      assert html =~ "1 members"
    end

    test "non-admin is redirected", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      assert {:error, {:live_redirect, _}} = live(conn, ~p"/admin/organisations")
    end
  end
end
