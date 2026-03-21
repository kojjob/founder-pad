defmodule FounderPadWeb.AgentCreateLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  describe "Agent creation page (unauthenticated)" do
    test "redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/agents/new")
    end
  end

  describe "Agent creation page (authenticated)" do
    test "renders the agent creation form", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, "/agents/new")
      assert html =~ "Create New Agent"
      assert html =~ "Agent Name"
      assert html =~ "System Prompt"
      assert html =~ "Temperature"
    end

    test "renders template presets", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, "/agents/new")
      assert html =~ "Research Assistant"
      assert html =~ "Code Reviewer"
      assert html =~ "Content Writer"
      assert html =~ "Custom"
    end

    test "selecting a template pre-fills the form", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, "/agents/new")

      html = render_click(view, "select_template", %{"template" => "research"})
      assert html =~ "Research Assistant"
    end

    test "creates an agent with valid data", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, "/agents/new")

      view
      |> form("#agent-form", %{
        "agent" => %{
          "name" => "My Test Agent",
          "description" => "A test description",
          "provider" => "anthropic",
          "model" => "claude-sonnet-4-20250514",
          "system_prompt" => "You are a test agent.",
          "temperature" => "0.7",
          "max_tokens" => "4096"
        }
      })
      |> render_submit()

      # Should redirect to the new agent's page
      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"/agents/"
    end

    test "shows error with missing required fields", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, "/agents/new")

      html =
        view
        |> form("#agent-form", %{
          "agent" => %{
            "name" => "",
            "system_prompt" => "",
            "provider" => "anthropic",
            "model" => "claude-sonnet-4-20250514"
          }
        })
        |> render_submit()

      assert html =~ "required" or html =~ "error" or html =~ "can&#39;t be blank"
    end
  end
end
