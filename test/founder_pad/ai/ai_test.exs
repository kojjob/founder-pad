defmodule FounderPad.AITest do
  use FounderPad.DataCase, async: true

  alias FounderPad.AI.{Agent, Conversation, Message, ToolCall}
  import FounderPad.Factory

  describe "Agent" do
    test "creates an agent for an org" do
      org = create_organisation!()

      assert {:ok, agent} =
               Agent
               |> Ash.Changeset.for_create(:create, %{
                 name: "Test Agent",
                 description: "A test agent",
                 system_prompt: "You are a test assistant.",
                 model: "claude-sonnet-4-20250514",
                 provider: :anthropic,
                 organisation_id: org.id
               })
               |> Ash.create()

      assert agent.name == "Test Agent"
      assert agent.provider == :anthropic
    end
  end

  describe "Conversation" do
    test "creates a conversation linking agent, org, and user" do
      org = create_organisation!()
      user = create_user!()
      agent = create_agent!(org)

      assert {:ok, conversation} =
               Conversation
               |> Ash.Changeset.for_create(:create, %{
                 title: "Test Conversation",
                 agent_id: agent.id,
                 organisation_id: org.id,
                 user_id: user.id
               })
               |> Ash.create()

      assert conversation.title == "Test Conversation"
      assert conversation.status == :active
    end
  end

  describe "Message" do
    test "creates a message in a conversation" do
      {_org, _user, _agent, conversation} = create_conversation_chain!()

      assert {:ok, message} =
               Message
               |> Ash.Changeset.for_create(:create, %{
                 role: :user,
                 content: "Hello, agent!",
                 conversation_id: conversation.id
               })
               |> Ash.create()

      assert message.role == :user
      assert message.content == "Hello, agent!"
    end
  end

  describe "ToolCall" do
    test "creates and completes a tool call" do
      {_org, _user, _agent, conversation} = create_conversation_chain!()

      {:ok, message} =
        Message
        |> Ash.Changeset.for_create(:create, %{
          role: :assistant,
          content: "Using tool...",
          conversation_id: conversation.id
        })
        |> Ash.create()

      {:ok, tool_call} =
        ToolCall
        |> Ash.Changeset.for_create(:create, %{
          tool_name: "search",
          input: %{"query" => "test"},
          message_id: message.id
        })
        |> Ash.create()

      assert tool_call.status == :pending

      {:ok, completed} =
        tool_call
        |> Ash.Changeset.for_update(:complete, %{
          output: %{"results" => ["found"]},
          duration_ms: 150
        })
        |> Ash.update()

      assert completed.status == :completed
      assert completed.duration_ms == 150
    end
  end

  describe "Provider behaviour" do
    test "Anthropic implements the behaviour callbacks" do
      # The behaviour defines chat/2, stream/2, models/0
      behaviours = FounderPad.AI.Providers.Anthropic.__info__(:functions)
      assert {:chat, 2} in behaviours
      assert {:stream, 2} in behaviours
      assert {:models, 0} in behaviours
    end

    test "OpenAI implements the behaviour callbacks" do
      behaviours = FounderPad.AI.Providers.OpenAI.__info__(:functions)
      assert {:chat, 2} in behaviours
      assert {:stream, 2} in behaviours
      assert {:models, 0} in behaviours
    end

    test "Anthropic lists models" do
      models = FounderPad.AI.Providers.Anthropic.models()
      assert "claude-sonnet-4-20250514" in models
    end

    test "OpenAI lists models" do
      models = FounderPad.AI.Providers.OpenAI.models()
      assert "gpt-4o" in models
    end
  end
end
