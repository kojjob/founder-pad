defmodule FounderPadWeb.UiPolishTest do
  use FounderPadWeb.ConnCase, async: false
  use FounderPad.LiveViewHelpers

  import Phoenix.LiveViewTest

  describe "Global search" do
    setup %{conn: conn} do
      {conn, user, _org} = setup_authenticated_user(conn)
      {:ok, conn: conn, user: user}
    end

    test "search form exists in the layout header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ ~s(phx-submit="global_search")
      assert html =~ ~s(name="q")
      assert html =~ ~s(placeholder="Search agents, settings...)
    end

    test "searching 'agent' navigates to /agents", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view
      |> form("#global-search-form", %{"q" => "agent"})
      |> render_submit()

      assert_redirected(view, "/agents")
    end

    test "searching 'billing' navigates to /billing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view
      |> form("#global-search-form", %{"q" => "billing"})
      |> render_submit()

      assert_redirected(view, "/billing")
    end

    test "searching 'team' navigates to /team", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view
      |> form("#global-search-form", %{"q" => "team"})
      |> render_submit()

      assert_redirected(view, "/team")
    end

    test "searching 'settings' navigates to /settings", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view
      |> form("#global-search-form", %{"q" => "settings"})
      |> render_submit()

      assert_redirected(view, "/settings")
    end

    test "searching unknown term navigates to /activity", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view
      |> form("#global-search-form", %{"q" => "something random"})
      |> render_submit()

      assert_redirected(view, "/activity")
    end

    test "searching empty string does nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      html =
        view
        |> form("#global-search-form", %{"q" => ""})
        |> render_submit()

      # Should stay on the same page (no redirect)
      assert html =~ "Dashboard"
    end
  end

  describe "Accessibility" do
    setup %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, conn: conn}
    end

    test "icon-only buttons have aria-labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Notification bell
      assert html =~ ~s(aria-label="Notifications")
      # Theme toggle
      assert html =~ ~s(aria-label="Toggle theme")
      # Mobile menu
      assert html =~ ~s(aria-label="Open navigation menu")
    end

    test "notification badge has aria-live for screen readers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # The notification area should have an aria-live region
      assert html =~ ~s(aria-live="polite")
    end

    test "mobile drawer has dialog role and aria-modal", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ ~s(role="dialog")
      assert html =~ ~s(aria-modal="true")
    end
  end
end
