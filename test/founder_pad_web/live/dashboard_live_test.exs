defmodule FounderPadWeb.DashboardLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "dashboard with real data" do
    test "renders with real agent count", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      Factory.create_agent!(org, %{name: "Agent Alpha", active: true})
      Factory.create_agent!(org, %{name: "Agent Beta", active: true})
      Factory.create_agent!(org, %{name: "Agent Gamma", active: false})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Total agents count should be 3
      assert html =~ "Active Agents"
      assert html =~ ">3</span>"
    end

    test "renders with real conversation count", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)

      agent = Factory.create_agent!(org)

      for title <- ["Chat 1", "Chat 2"] do
        FounderPad.AI.Conversation
        |> Ash.Changeset.for_create(:create, %{
          title: title,
          agent_id: agent.id,
          organisation_id: org.id,
          user_id: user.id
        })
        |> Ash.create!()
      end

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Total Conversations"
      assert html =~ ">2</span>"
    end

    test "shows zero state when no data exists", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Active Agents"
      assert html =~ ">0</span>"
      assert html =~ "Total Conversations"
    end

    test "agent activity section shows real agents", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      Factory.create_agent!(org, %{
        name: "Sales Bot",
        active: true,
        provider: :anthropic,
        model: "claude-sonnet-4-20250514"
      })

      Factory.create_agent!(org, %{
        name: "Support Bot",
        active: false,
        provider: :openai,
        model: "gpt-4"
      })

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Sales Bot"
      assert html =~ "Support Bot"
      assert html =~ "Anthropic"
      assert html =~ "Openai"
      assert html =~ "Running"
      assert html =~ "Paused"
    end

    test "shows empty state message when no agents exist for activity", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "No agent activity yet"
    end

    test "displays usage record count as token usage", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      for _ <- 1..3 do
        FounderPad.Billing.UsageRecord
        |> Ash.Changeset.for_create(:create, %{
          event_type: "api_call",
          quantity: 1,
          organisation_id: org.id
        })
        |> Ash.create!()
      end

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "API Usage"
      assert html =~ ">3</span>"
    end
  end

  describe "dashboard refresh" do
    test "refresh updates metrics when new data is added", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      {:ok, view, html} = live(conn, ~p"/dashboard")

      # Initially 0 agents
      assert html =~ ">0</span>"
      assert html =~ "No agent activity yet"

      # Create an agent
      Factory.create_agent!(org, %{name: "New Agent"})

      # Trigger refresh
      send(view.pid, :refresh)

      html = render(view)

      # Now should show 1 agent and the agent in activity
      assert html =~ ">1</span>"
      assert html =~ "New Agent"
      refute html =~ "No agent activity yet"
    end
  end
end
