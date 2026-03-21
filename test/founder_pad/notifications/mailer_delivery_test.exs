defmodule FounderPad.Notifications.MailerDeliveryTest do
  use FounderPad.DataCase, async: true

  import Swoosh.TestAssertions
  import FounderPad.Factory

  alias FounderPad.AI.Workers.AgentRunner
  alias FounderPad.Notifications.{AgentMailer, AuthMailer}

  describe "agent completion email delivery" do
    setup do
      {org, user, agent, conversation} = create_conversation_chain!()

      # Load the agent relationship on the conversation
      {:ok, conversation} = Ash.load(conversation, :agent)

      # Clear the welcome email triggered by user registration
      receive do
        {:email, _} -> :ok
      after
        100 -> :ok
      end

      %{org: org, user: user, agent: agent, conversation: conversation}
    end

    test "sends email when agent run completes", %{
      user: user,
      agent: agent,
      conversation: conversation
    } do
      AgentRunner.notify_agent_completed(conversation, agent)

      assert_email_sent(
        to: [{user.name || "User", to_string(user.email)}],
        subject: "Agent \"#{agent.name}\" completed a run"
      )
    end

    test "sends email when agent run fails", %{
      user: user,
      conversation: conversation
    } do
      AgentRunner.notify_agent_failed(conversation, "Provider timeout")

      assert_email_sent(
        to: [{user.name || "User", to_string(user.email)}],
        subject: ~r/failed/
      )
    end

    test "completion email contains link to conversation", %{
      agent: agent,
      conversation: conversation
    } do
      AgentRunner.notify_agent_completed(conversation, agent)

      assert_email_sent(fn email ->
        assert email.html_body =~ "/conversations/#{conversation.id}"
      end)
    end

    test "failure email contains the error reason", %{
      conversation: conversation
    } do
      AgentRunner.notify_agent_failed(conversation, "Rate limit exceeded")

      assert_email_sent(fn email ->
        assert email.html_body =~ "Rate limit exceeded"
      end)
    end
  end

  describe "agent mailer unit tests" do
    test "agent_run_completed/3 builds and sends correct email" do
      user = %{name: "Jane", email: "jane@example.com"}
      agent = %{name: "Research Bot", id: "agent-123"}
      conversation = %{id: "conv-456"}

      AgentMailer.agent_run_completed(user, agent, conversation)

      assert_email_sent(
        to: [{"Jane", "jane@example.com"}],
        subject: "Agent \"Research Bot\" completed a run"
      )
    end

    test "agent_run_failed/3 builds and sends correct email" do
      user = %{name: "Jane", email: "jane@example.com"}
      agent = %{name: "Research Bot", id: "agent-123"}

      AgentMailer.agent_run_failed(user, agent, "Connection timeout")

      assert_email_sent(
        to: [{"Jane", "jane@example.com"}],
        subject: "Agent \"Research Bot\" run failed"
      )
    end
  end

  describe "auth mailer unit tests" do
    test "welcome/1 sends welcome email" do
      user = %{name: "Alice", email: "alice@example.com"}

      AuthMailer.welcome(user)

      assert_email_sent(
        to: [{"Alice", "alice@example.com"}],
        subject: "Welcome to FounderPad!"
      )
    end

    test "welcome email without name uses fallback" do
      user = %{name: nil, email: "noname@example.com"}

      AuthMailer.welcome(user)

      assert_email_sent(
        to: [{"User", "noname@example.com"}],
        subject: "Welcome to FounderPad!"
      )
    end
  end

  describe "welcome email on registration" do
    test "sends welcome email when a new user registers" do
      _user = create_user!(email: "newuser@example.com", password: "Password123!")

      assert_email_sent(
        subject: "Welcome to FounderPad!"
      )
    end
  end
end
