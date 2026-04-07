defmodule FounderPadWeb.Help.HelpIndexLiveTest do
  use FounderPadWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FounderPad.Factory

  test "shows help categories", %{conn: conn} do
    admin = create_admin_user!()
    create_help_category!(%{name: "Getting Started", actor: admin})

    {:ok, _view, html} = live(conn, ~p"/help")
    assert html =~ "Getting Started"
  end

  test "shows search bar", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/help")
    assert html =~ "search" or html =~ "Search"
  end

  test "search returns results", %{conn: conn} do
    admin = create_admin_user!()
    cat = create_help_category!(%{actor: admin})

    create_published_help_article!(cat, %{
      title: "Billing Help",
      body: "How to manage billing.",
      actor: admin
    })

    {:ok, _view, html} = live(conn, ~p"/help/search?q=billing")
    assert html =~ "Billing Help"
  end
end
