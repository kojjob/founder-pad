defmodule FounderPadWeb.FeedControllerTest do
  use FounderPadWeb.ConnCase, async: true

  import FounderPad.Factory

  test "GET /blog/feed.xml returns RSS with published posts", %{conn: conn} do
    admin = create_admin_user!()
    create_published_post!(%{title: "Test RSS Post", actor: admin})

    conn = get(conn, "/blog/feed.xml")
    body = response(conn, 200)
    assert body =~ "Test RSS Post"
    assert body =~ "<rss version=\"2.0\""
    assert body =~ "FounderPad Blog"
  end

  test "GET /blog/feed.xml does not include draft posts", %{conn: conn} do
    admin = create_admin_user!()
    create_post!(%{title: "Draft Only Post", status: :draft, actor: admin})

    conn = get(conn, "/blog/feed.xml")
    body = response(conn, 200)
    refute body =~ "Draft Only Post"
  end

  test "GET /changelog/feed.xml returns RSS with published entries", %{conn: conn} do
    admin = create_admin_user!()
    entry = create_changelog_entry!(%{title: "New Feature", version: "v1.0.0", actor: admin})

    entry
    |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
    |> Ash.update!()

    conn = get(conn, "/changelog/feed.xml")
    body = response(conn, 200)
    assert body =~ "New Feature"
    assert body =~ "v1.0.0"
    assert body =~ "<rss version=\"2.0\""
    assert body =~ "FounderPad Changelog"
  end

  test "GET /changelog/feed.xml does not include draft entries", %{conn: conn} do
    admin = create_admin_user!()
    create_changelog_entry!(%{title: "Draft Entry", actor: admin})

    conn = get(conn, "/changelog/feed.xml")
    body = response(conn, 200)
    refute body =~ "Draft Entry"
  end

  test "GET /blog/feed.xml returns valid XML structure", %{conn: conn} do
    conn = get(conn, "/blog/feed.xml")
    body = response(conn, 200)
    assert body =~ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    assert body =~ "<channel>"
    assert body =~ "</channel>"
    assert body =~ "xmlns:atom"
  end
end
