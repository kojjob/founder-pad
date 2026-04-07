defmodule LinkHub.MessagingTest do
  use LinkHub.DataCase, async: true

  alias LinkHub.Factory

  require Ash.Query

  describe "Channel" do
    test "creates a channel with auto-generated slug" do
      {workspace, user, _channel} = Factory.create_messaging_context!()

      channel =
        Factory.create_channel!(workspace, user, %{name: "Design Team"})

      assert channel.name == "Design Team"
      assert channel.slug == "design-team"
      assert channel.visibility == :public
      assert channel.workspace_id == workspace.id
    end

    test "creates a private channel" do
      {workspace, user, _channel} = Factory.create_messaging_context!()

      channel =
        Factory.create_channel!(workspace, user, %{
          name: "Secret Project",
          visibility: :private
        })

      assert channel.visibility == :private
    end

    test "enforces unique slug per workspace" do
      {workspace, user, _channel} = Factory.create_messaging_context!()

      Factory.create_channel!(workspace, user, %{name: "general"})

      assert_raise Ash.Error.Invalid, fn ->
        Factory.create_channel!(workspace, user, %{name: "general"})
      end
    end

    test "lists active channels for a workspace" do
      {workspace, user, channel} = Factory.create_messaging_context!()
      channel2 = Factory.create_channel!(workspace, user, %{name: "engineering"})

      # Archive one
      Ash.Changeset.for_update(channel2, :archive) |> Ash.update!()

      channels =
        LinkHub.Messaging.Channel
        |> Ash.Query.for_read(:list_by_workspace, %{workspace_id: workspace.id})
        |> Ash.read!()

      assert length(channels) == 1
      assert hd(channels).id == channel.id
    end
  end

  describe "ChannelMembership" do
    test "user can join a channel" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      user2 = Factory.create_user!()

      membership = Factory.join_channel!(channel, user2)

      assert membership.channel_id == channel.id
      assert membership.user_id == user2.id
    end

    test "prevents duplicate membership" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      assert_raise Ash.Error.Invalid, fn ->
        Factory.join_channel!(channel, user)
      end
    end

    test "user can leave a channel" do
      {_workspace, _user, channel} = Factory.create_messaging_context!()

      user2 = Factory.create_user!()
      Factory.join_channel!(channel, user2)

      LinkHub.Messaging.ChannelMembership
      |> Ash.ActionInput.for_action(:leave, %{channel_id: channel.id, user_id: user2.id})
      |> Ash.run_action!()

      memberships =
        LinkHub.Messaging.ChannelMembership
        |> Ash.Query.filter(channel_id == ^channel.id and user_id == ^user2.id)
        |> Ash.read!()

      assert memberships == []
    end
  end

  describe "Message" do
    test "sends a message to a channel" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      message = Factory.send_message!(channel, user, "Hello, world!")

      assert message.body == "Hello, world!"
      assert message.channel_id == channel.id
      assert message.author_id == user.id
      assert is_nil(message.parent_message_id)
    end

    test "sends a threaded reply" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      parent = Factory.send_message!(channel, user, "Start of thread")

      reply =
        Factory.send_message!(channel, user, "This is a reply", %{
          parent_message_id: parent.id
        })

      assert reply.parent_message_id == parent.id
    end

    test "lists messages by channel in order" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      msg1 = Factory.send_message!(channel, user, "First")
      msg2 = Factory.send_message!(channel, user, "Second")

      messages =
        LinkHub.Messaging.Message
        |> Ash.Query.for_read(:list_by_channel, %{channel_id: channel.id})
        |> Ash.read!()

      assert length(messages) == 2
      assert Enum.map(messages, & &1.id) == [msg1.id, msg2.id]
    end

    test "edits a message" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      message = Factory.send_message!(channel, user, "Original")

      updated =
        message
        |> Ash.Changeset.for_update(:edit, %{body: "Edited"})
        |> Ash.update!()

      assert updated.body == "Edited"
      refute is_nil(updated.edited_at)
    end

    test "soft deletes a message" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      message = Factory.send_message!(channel, user, "Delete me")

      deleted =
        message
        |> Ash.Changeset.for_update(:soft_delete)
        |> Ash.update!()

      assert deleted.body == "[deleted]"
      refute is_nil(deleted.deleted_at)

      # Soft-deleted messages are excluded from list
      messages =
        LinkHub.Messaging.Message
        |> Ash.Query.for_read(:list_by_channel, %{channel_id: channel.id})
        |> Ash.read!()

      assert messages == []
    end

    test "counts replies on a message" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      parent = Factory.send_message!(channel, user, "Parent")
      Factory.send_message!(channel, user, "Reply 1", %{parent_message_id: parent.id})
      Factory.send_message!(channel, user, "Reply 2", %{parent_message_id: parent.id})

      parent_with_count = Ash.load!(parent, :reply_count)
      assert parent_with_count.reply_count == 2
    end
  end

  describe "Reaction" do
    test "adds a reaction to a message" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      message = Factory.send_message!(channel, user, "React to me")
      reaction = Factory.add_reaction!(message, user, "thumbsup")

      assert reaction.emoji == "thumbsup"
      assert reaction.message_id == message.id
      assert reaction.user_id == user.id
    end

    test "prevents duplicate reactions" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      message = Factory.send_message!(channel, user, "React once")
      Factory.add_reaction!(message, user, "thumbsup")

      assert_raise Ash.Error.Invalid, fn ->
        Factory.add_reaction!(message, user, "thumbsup")
      end
    end

    test "allows different emojis from same user" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      message = Factory.send_message!(channel, user, "React many")
      Factory.add_reaction!(message, user, "thumbsup")
      reaction2 = Factory.add_reaction!(message, user, "heart")

      assert reaction2.emoji == "heart"
    end

    test "removes a reaction" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      message = Factory.send_message!(channel, user, "React and remove")
      Factory.add_reaction!(message, user, "thumbsup")

      LinkHub.Messaging.Reaction
      |> Ash.ActionInput.for_action(:remove, %{
        message_id: message.id,
        user_id: user.id,
        emoji: "thumbsup"
      })
      |> Ash.run_action!()

      reactions =
        LinkHub.Messaging.Reaction
        |> Ash.Query.filter(message_id == ^message.id)
        |> Ash.read!()

      assert reactions == []
    end
  end

  describe "ReadReceipt" do
    test "marks a channel as read" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      message = Factory.send_message!(channel, user, "Read me")

      receipt =
        LinkHub.Messaging.ReadReceipt
        |> Ash.Changeset.for_create(:mark, %{
          channel_id: channel.id,
          user_id: user.id,
          last_read_message_id: message.id
        })
        |> Ash.create!()

      assert receipt.channel_id == channel.id
      assert receipt.user_id == user.id
      refute is_nil(receipt.last_read_at)
    end

    test "upserts on repeated reads" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      msg1 = Factory.send_message!(channel, user, "First")
      msg2 = Factory.send_message!(channel, user, "Second")

      LinkHub.Messaging.ReadReceipt
      |> Ash.Changeset.for_create(:mark, %{
        channel_id: channel.id,
        user_id: user.id,
        last_read_message_id: msg1.id
      })
      |> Ash.create!()

      # Second mark should upsert
      receipt2 =
        LinkHub.Messaging.ReadReceipt
        |> Ash.Changeset.for_create(:mark, %{
          channel_id: channel.id,
          user_id: user.id,
          last_read_message_id: msg2.id
        })
        |> Ash.create!()

      assert receipt2.last_read_message_id == msg2.id

      # Should still only have one receipt
      receipts =
        LinkHub.Messaging.ReadReceipt
        |> Ash.Query.filter(channel_id == ^channel.id and user_id == ^user.id)
        |> Ash.read!()

      assert length(receipts) == 1
    end
  end

  describe "MessageNotifier" do
    test "broadcasts new message to PubSub" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      Phoenix.PubSub.subscribe(LinkHub.PubSub, "channel:#{channel.id}")

      Factory.send_message!(channel, user, "Hello PubSub!")

      assert_receive {:new_message, message}
      assert message.body == "Hello PubSub!"
    end

    test "broadcasts message edit to PubSub" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      message = Factory.send_message!(channel, user, "Original")

      Phoenix.PubSub.subscribe(LinkHub.PubSub, "channel:#{channel.id}")

      message
      |> Ash.Changeset.for_update(:edit, %{body: "Edited"})
      |> Ash.update!()

      assert_receive {:message_edited, edited}
      assert edited.body == "Edited"
    end

    test "broadcasts message deletion to PubSub" do
      {_workspace, user, channel} = Factory.create_messaging_context!()

      message = Factory.send_message!(channel, user, "Delete me")

      Phoenix.PubSub.subscribe(LinkHub.PubSub, "channel:#{channel.id}")

      message
      |> Ash.Changeset.for_update(:soft_delete)
      |> Ash.update!()

      assert_receive {:message_deleted, deleted}
      assert deleted.body == "[deleted]"
    end
  end
end
