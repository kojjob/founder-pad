defmodule FounderPadWeb.AgentTemplatesLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "agent templates page" do
    test "renders templates page", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/agents/templates")

      assert html =~ "Agent Templates"
      assert html =~ "Pre-built agent templates"
    end

    test "shows empty state when no templates", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/agents/templates")

      assert html =~ "No templates available yet"
    end

    test "shows template cards when templates exist", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      admin = Factory.create_admin_user!()

      FounderPad.AI.AgentTemplate
      |> Ash.Changeset.for_create(
        :create,
        %{
          name: "Sales Assistant",
          description: "Helps with sales outreach",
          category: "Sales",
          system_prompt: "You are a sales assistant.",
          icon: "storefront"
        }, actor: admin)
      |> Ash.create!()

      {:ok, _view, html} = live(conn, ~p"/agents/templates")

      assert html =~ "Sales Assistant"
      assert html =~ "Helps with sales outreach"
      assert html =~ "Sales"
      assert html =~ "Use Template"
    end

    test "filters templates by category", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      admin = Factory.create_admin_user!()

      FounderPad.AI.AgentTemplate
      |> Ash.Changeset.for_create(
        :create,
        %{
          name: "Sales Bot",
          category: "Sales",
          system_prompt: "Sales assistant"
        }, actor: admin)
      |> Ash.create!()

      FounderPad.AI.AgentTemplate
      |> Ash.Changeset.for_create(
        :create,
        %{
          name: "Support Bot",
          category: "Support",
          system_prompt: "Support assistant"
        }, actor: admin)
      |> Ash.create!()

      {:ok, view, _html} = live(conn, ~p"/agents/templates")

      html = view |> element("button", "Sales") |> render_click()

      assert html =~ "Sales Bot"
      refute html =~ "Support Bot"
    end

    test "use template creates agent and redirects", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      admin = Factory.create_admin_user!()

      {:ok, template} =
        FounderPad.AI.AgentTemplate
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Research Helper",
            description: "Helps with research",
            category: "Research",
            system_prompt: "You are a research assistant."
          }, actor: admin)
        |> Ash.create()

      {:ok, view, _html} = live(conn, ~p"/agents/templates")

      view |> element("button", "Use Template") |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path =~ "/agents/"
    end
  end
end
