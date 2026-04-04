defmodule FounderPadWeb.WidgetConfigLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "widget config page" do
    test "renders widget config for an agent", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org, %{name: "Support Bot"})

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent.id}/widget")

      assert html =~ "Embed Chat Widget"
      assert html =~ "Support Bot"
      assert html =~ "Embed Code"
    end

    test "shows embed code snippet", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org)

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent.id}/widget")

      assert html =~ "/widget/embed/#{agent.id}"
      assert html =~ "script"
    end

    test "shows customization options", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org)

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent.id}/widget")

      assert html =~ "Customization"
      assert html =~ "Widget Color"
      assert html =~ "Position"
      assert html =~ "Bottom Right"
      assert html =~ "Bottom Left"
    end

    test "shows preview iframe", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org)

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent.id}/widget")

      assert html =~ "Preview"
      assert html =~ "/widget/chat/#{agent.id}"
    end

    test "redirects for non-existent agent", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      assert {:error, {:live_redirect, %{to: "/agents"}}} =
               live(conn, ~p"/agents/#{Ash.UUID.generate()}/widget")
    end
  end
end
