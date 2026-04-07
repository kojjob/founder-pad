defmodule FounderPadWeb.AgentAnalyticsLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "agent analytics page" do
    test "renders analytics dashboard for an agent", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org, %{name: "Analytics Bot"})

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent.id}/analytics")

      assert html =~ "Analytics Bot"
      assert html =~ "Agent Analytics"
      assert html =~ "Total Conversations"
      assert html =~ "Total Messages"
      assert html =~ "Tool Calls"
      assert html =~ "Token Usage"
      assert html =~ "Total Cost"
      assert html =~ "Avg Response Time"
    end

    test "shows correct conversation count", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org, %{name: "Busy Bot"})

      for i <- 1..3 do
        FounderPad.AI.Conversation
        |> Ash.Changeset.for_create(:create, %{
          title: "Conv #{i}",
          agent_id: agent.id,
          organisation_id: org.id,
          user_id: user.id
        })
        |> Ash.create!()
      end

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent.id}/analytics")

      assert html =~ "Total Conversations"
      assert html =~ ">3<"
    end

    test "shows message and token metrics", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org, %{name: "Token Bot"})

      conversation =
        FounderPad.AI.Conversation
        |> Ash.Changeset.for_create(:create, %{
          title: "Test Conv",
          agent_id: agent.id,
          organisation_id: org.id,
          user_id: user.id
        })
        |> Ash.create!()

      for {role, tokens, cost} <- [{:user, 100, 5}, {:assistant, 500, 25}, {:user, 150, 8}] do
        FounderPad.AI.Message
        |> Ash.Changeset.for_create(:create, %{
          role: role,
          content: "Test message",
          token_count: tokens,
          cost_cents: cost,
          conversation_id: conversation.id
        })
        |> Ash.create!()
      end

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent.id}/analytics")

      assert html =~ "Total Messages"
      assert html =~ ">3<"
      assert html =~ "750"
      assert html =~ "$0.38"
    end

    test "shows tool call success/failure rates", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org, %{name: "Tool Bot"})

      conversation =
        FounderPad.AI.Conversation
        |> Ash.Changeset.for_create(:create, %{
          title: "Tool Conv",
          agent_id: agent.id,
          organisation_id: org.id,
          user_id: user.id
        })
        |> Ash.create!()

      message =
        FounderPad.AI.Message
        |> Ash.Changeset.for_create(:create, %{
          role: :assistant,
          content: "Using tools",
          conversation_id: conversation.id
        })
        |> Ash.create!()

      # Create completed and failed tool calls
      for status <- [:completed, :completed, :completed, :failed] do
        FounderPad.AI.ToolCall
        |> Ash.Changeset.for_create(:create, %{
          tool_name: "test_tool",
          status: status,
          message_id: message.id
        })
        |> Ash.create!()
      end

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent.id}/analytics")

      assert html =~ "Tool Calls"
      assert html =~ ">4<"
      assert html =~ "Success Rate"
      assert html =~ "75.0%"
    end

    test "shows zero state when agent has no data", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org, %{name: "Empty Bot"})

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent.id}/analytics")

      assert html =~ "Empty Bot"
      assert html =~ ">0<"
    end

    test "shows average response time from tool call durations", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org, %{name: "Fast Bot"})

      conversation =
        FounderPad.AI.Conversation
        |> Ash.Changeset.for_create(:create, %{
          title: "Speed Conv",
          agent_id: agent.id,
          organisation_id: org.id,
          user_id: user.id
        })
        |> Ash.create!()

      message =
        FounderPad.AI.Message
        |> Ash.Changeset.for_create(:create, %{
          role: :assistant,
          content: "Quick response",
          conversation_id: conversation.id
        })
        |> Ash.create!()

      # Create tool calls with known durations
      tc1 =
        FounderPad.AI.ToolCall
        |> Ash.Changeset.for_create(:create, %{
          tool_name: "fast_tool",
          status: :pending,
          message_id: message.id
        })
        |> Ash.create!()

      tc1
      |> Ash.Changeset.for_update(:complete, %{output: %{}, duration_ms: 200})
      |> Ash.update!()

      tc2 =
        FounderPad.AI.ToolCall
        |> Ash.Changeset.for_create(:create, %{
          tool_name: "slow_tool",
          status: :pending,
          message_id: message.id
        })
        |> Ash.create!()

      tc2
      |> Ash.Changeset.for_update(:complete, %{output: %{}, duration_ms: 400})
      |> Ash.update!()

      {:ok, _view, html} = live(conn, ~p"/agents/#{agent.id}/analytics")

      assert html =~ "Avg Response Time"
      assert html =~ "300ms"
    end
  end
end
