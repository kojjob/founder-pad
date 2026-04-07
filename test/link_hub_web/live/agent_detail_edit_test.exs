defmodule LinkHubWeb.AgentDetailEditTest do
  use LinkHubWeb.ConnCase, async: true
  use LinkHub.LiveViewHelpers
  import LinkHub.Factory

  describe "Agent config editing" do
    test "config tab shows system prompt", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org, system_prompt: "Test prompt here")
      {:ok, view, _html} = live(conn, "/agents/#{agent.id}")
      render_click(view, "set_tab", %{"tab" => "config"})
      html = render(view)
      assert html =~ "Test prompt here"
    end

    test "save config persists system prompt", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org)
      {:ok, view, _html} = live(conn, "/agents/#{agent.id}")
      render_click(view, "set_tab", %{"tab" => "config"})
      render_change(view, "update_system_prompt", %{"value" => "New prompt"})
      render_click(view, "save_config")
      updated = Ash.get!(LinkHub.AI.Agent, agent.id)
      assert updated.system_prompt == "New prompt"
    end

    test "save config updates model", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org)
      {:ok, view, _html} = live(conn, "/agents/#{agent.id}")
      render_click(view, "set_tab", %{"tab" => "config"})
      render_change(view, "change_model", %{"model" => "gpt-4o"})
      render_change(view, "change_provider", %{"provider" => "openai"})
      render_click(view, "save_config")
      updated = Ash.get!(LinkHub.AI.Agent, agent.id)
      assert updated.provider == :openai
    end
  end
end
