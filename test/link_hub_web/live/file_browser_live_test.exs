defmodule LinkHubWeb.FileBrowserLiveTest do
  use LinkHubWeb.ConnCase, async: true
  use LinkHub.LiveViewHelpers

  alias LinkHub.Factory

  defp mark_ready!(file) do
    file
    |> Ash.Changeset.for_update(:mark_ready, %{})
    |> Ash.update!()
  end

  describe "file browser" do
    test "renders the files page with empty state when no files exist", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/files")

      assert html =~ "Files"
      assert html =~ "No files found"
    end

    test "displays files when they exist in the workspace", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)

      Factory.create_stored_file!(org, user, %{
        filename: "quarterly-report.pdf",
        content_type: "application/pdf",
        size_bytes: 2_500_000
      })
      |> mark_ready!()

      Factory.create_stored_file!(org, user, %{
        filename: "team-photo.png",
        content_type: "image/png",
        size_bytes: 512_000
      })
      |> mark_ready!()

      {:ok, _view, html} = live(conn, ~p"/files")

      assert html =~ "quarterly-report.pdf"
      assert html =~ "application/pdf"
      assert html =~ "2.4 MB"

      assert html =~ "team-photo.png"
      assert html =~ "image/png"
      assert html =~ "500.0 KB"

      refute html =~ "No files found"
    end

    test "only shows ready files by default", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)

      Factory.create_stored_file!(org, user, %{filename: "ready-file.png"})
      |> mark_ready!()

      Factory.create_stored_file!(org, user, %{filename: "pending-file.png"})

      {:ok, _view, html} = live(conn, ~p"/files")

      assert html =~ "ready-file.png"
      refute html =~ "pending-file.png"
    end

    test "search filters results by filename", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)

      Factory.create_stored_file!(org, user, %{
        filename: "budget-2026.xlsx",
        content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      })
      |> mark_ready!()

      Factory.create_stored_file!(org, user, %{
        filename: "logo-dark.svg",
        content_type: "image/svg+xml"
      })
      |> mark_ready!()

      {:ok, view, _html} = live(conn, ~p"/files")

      html = view |> element("#file-search-form") |> render_change(%{"query" => "budget"})

      assert html =~ "budget-2026.xlsx"
      refute html =~ "logo-dark.svg"
    end

    test "search shows empty state when no matches", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)

      Factory.create_stored_file!(org, user, %{filename: "readme.txt"})
      |> mark_ready!()

      {:ok, view, _html} = live(conn, ~p"/files")

      html = view |> element("#file-search-form") |> render_change(%{"query" => "nonexistent"})

      assert html =~ "No files found"
      refute html =~ "readme.txt"
    end
  end
end
