defmodule FounderPadWeb.Admin.ChangelogListLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "admin changelog list" do
    test "admin can see all changelog entries", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      Factory.create_changelog_entry!(%{title: "Draft Release", version: "v0.1.0", actor: admin})

      entry = Factory.create_changelog_entry!(%{title: "Published Release", version: "v1.0.0", actor: admin})

      entry
      |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
      |> Ash.update!()

      {:ok, _view, html} = live(conn, ~p"/admin/changelog")

      assert html =~ "Changelog Entries"
      assert html =~ "Draft Release"
      assert html =~ "Published Release"
      assert html =~ "v0.1.0"
      assert html =~ "v1.0.0"
    end

    test "non-admin is redirected", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      assert {:error, {:live_redirect, _}} = live(conn, ~p"/admin/changelog")
    end

    test "can publish a draft entry", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      Factory.create_changelog_entry!(%{title: "My Draft Entry", version: "v2.0.0", actor: admin})

      {:ok, view, html} = live(conn, ~p"/admin/changelog")

      assert html =~ "My Draft Entry"
      assert html =~ "Draft"

      view
      |> element("button[phx-click=publish]")
      |> render_click()

      html = render(view)
      assert html =~ "Published"
      assert html =~ "Entry published successfully."
    end

    test "can delete an entry", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      Factory.create_changelog_entry!(%{title: "To Delete", version: "v3.0.0", actor: admin})

      {:ok, view, html} = live(conn, ~p"/admin/changelog")

      assert html =~ "To Delete"

      view
      |> element("button[phx-click=delete]")
      |> render_click()

      html = render(view)
      refute html =~ "To Delete"
      assert html =~ "Entry deleted."
    end

    test "shows new entry link", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, _view, html} = live(conn, ~p"/admin/changelog")

      assert html =~ "New Entry"
      assert html =~ "/admin/changelog/new"
    end

    test "displays type badges correctly", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      Factory.create_changelog_entry!(%{title: "A Feature", type: :feature, version: "v1.0.0", actor: admin})
      Factory.create_changelog_entry!(%{title: "A Fix", type: :fix, version: "v1.0.1", actor: admin})

      {:ok, _view, html} = live(conn, ~p"/admin/changelog")

      assert html =~ "Feature"
      assert html =~ "Fix"
    end
  end
end
