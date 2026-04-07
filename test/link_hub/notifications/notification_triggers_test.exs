defmodule LinkHub.Notifications.NotificationTriggersTest do
  use LinkHub.DataCase, async: true

  alias LinkHub.AI.Workers.AgentRunner
  alias LinkHub.Notifications.Notification

  require Ash.Query

  import LinkHub.Factory

  describe "agent run completion notifications" do
    setup do
      {org, user, agent, conversation} = create_conversation_chain!()
      %{org: org, user: user, agent: agent, conversation: conversation}
    end

    test "creates agent_completed notification on successful run", %{
      user: user,
      agent: agent,
      conversation: conversation
    } do
      AgentRunner.notify_agent_completed(conversation, agent)

      notifications =
        Notification
        |> Ash.Query.filter(user_id: user.id, type: :agent_completed)
        |> Ash.read!()

      assert length(notifications) == 1
      notif = hd(notifications)
      assert notif.type == :agent_completed
      assert notif.title == "#{agent.name} completed a run"
      assert notif.body == "Agent run completed successfully"
      assert notif.action_url == "/agents/#{agent.id}"
    end

    test "creates agent_failed notification on failed run", %{
      user: user,
      conversation: conversation
    } do
      # Load conversation with user_id to simulate what the runner does
      AgentRunner.notify_agent_failed(conversation, "Provider timeout")

      notifications =
        Notification
        |> Ash.Query.filter(user_id: user.id, type: :agent_failed)
        |> Ash.read!()

      assert length(notifications) == 1
      notif = hd(notifications)
      assert notif.type == :agent_failed
      assert notif.title == "Agent run failed"
      assert notif.body =~ "Provider timeout"
    end

    test "notification has correct type for completed run", %{
      agent: agent,
      conversation: conversation
    } do
      AgentRunner.notify_agent_completed(conversation, agent)

      notifications =
        Notification
        |> Ash.Query.filter(type: :agent_completed)
        |> Ash.read!()

      notif = hd(notifications)
      assert notif.type == :agent_completed
    end

    test "notification links to correct agent page", %{
      agent: agent,
      conversation: conversation
    } do
      AgentRunner.notify_agent_completed(conversation, agent)

      notifications =
        Notification
        |> Ash.Query.filter(type: :agent_completed)
        |> Ash.read!()

      notif = hd(notifications)
      assert notif.action_url == "/agents/#{agent.id}"
    end

    test "broadcasts notification via PubSub on completion", %{
      user: user,
      agent: agent,
      conversation: conversation
    } do
      Phoenix.PubSub.subscribe(LinkHub.PubSub, "user_notifications:#{user.id}")

      AgentRunner.notify_agent_completed(conversation, agent)

      assert_receive {:new_notification, %{type: :agent_completed}}
    end

    test "broadcasts notification via PubSub on failure", %{
      user: user,
      conversation: conversation
    } do
      Phoenix.PubSub.subscribe(LinkHub.PubSub, "user_notifications:#{user.id}")

      AgentRunner.notify_agent_failed(conversation, "Connection refused")

      assert_receive {:new_notification, %{type: :agent_failed}}
    end
  end
end
