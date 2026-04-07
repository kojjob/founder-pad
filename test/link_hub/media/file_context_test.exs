defmodule LinkHub.Media.FileContextTest do
  use LinkHub.DataCase, async: true
  alias LinkHub.Factory
  require Ash.Query

  setup do
    {workspace, user, channel} = Factory.create_messaging_context!()
    stored_file = Factory.create_stored_file!(workspace, user)
    message = Factory.send_message!(channel, user, "Hello with attachment")

    %{
      workspace: workspace,
      user: user,
      channel: channel,
      stored_file: stored_file,
      message: message
    }
  end

  describe "create action" do
    test "links a stored file to a message", ctx do
      assert {:ok, file_context} =
               LinkHub.Media.FileContext
               |> Ash.Changeset.for_create(:create, %{
                 context_type: :message,
                 stored_file_id: ctx.stored_file.id,
                 message_id: ctx.message.id
               })
               |> Ash.create()

      assert file_context.context_type == :message
      assert file_context.stored_file_id == ctx.stored_file.id
      assert file_context.message_id == ctx.message.id
    end

    test "links a stored file to a channel", ctx do
      assert {:ok, file_context} =
               LinkHub.Media.FileContext
               |> Ash.Changeset.for_create(:create, %{
                 context_type: :channel,
                 stored_file_id: ctx.stored_file.id,
                 channel_id: ctx.channel.id
               })
               |> Ash.create()

      assert file_context.context_type == :channel
      assert file_context.stored_file_id == ctx.stored_file.id
      assert file_context.channel_id == ctx.channel.id
    end
  end

  describe "list_by_message action" do
    test "returns contexts for a given message with loaded stored_file", ctx do
      LinkHub.Media.FileContext
      |> Ash.Changeset.for_create(:create, %{
        context_type: :message,
        stored_file_id: ctx.stored_file.id,
        message_id: ctx.message.id
      })
      |> Ash.create!()

      results =
        LinkHub.Media.FileContext
        |> Ash.Query.for_read(:list_by_message, %{message_id: ctx.message.id})
        |> Ash.read!()

      assert length(results) == 1
      [file_context] = results
      assert file_context.message_id == ctx.message.id
      assert %LinkHub.Media.StoredFile{} = file_context.stored_file
      assert file_context.stored_file.id == ctx.stored_file.id
    end

    test "does not return contexts for a different message", ctx do
      LinkHub.Media.FileContext
      |> Ash.Changeset.for_create(:create, %{
        context_type: :message,
        stored_file_id: ctx.stored_file.id,
        message_id: ctx.message.id
      })
      |> Ash.create!()

      other_message = Factory.send_message!(ctx.channel, ctx.user, "Other message")

      results =
        LinkHub.Media.FileContext
        |> Ash.Query.for_read(:list_by_message, %{message_id: other_message.id})
        |> Ash.read!()

      assert results == []
    end
  end

  describe "list_by_channel action" do
    test "returns contexts for a given channel with loaded stored_file", ctx do
      LinkHub.Media.FileContext
      |> Ash.Changeset.for_create(:create, %{
        context_type: :channel,
        stored_file_id: ctx.stored_file.id,
        channel_id: ctx.channel.id
      })
      |> Ash.create!()

      results =
        LinkHub.Media.FileContext
        |> Ash.Query.for_read(:list_by_channel, %{channel_id: ctx.channel.id})
        |> Ash.read!()

      assert length(results) == 1
      [file_context] = results
      assert file_context.channel_id == ctx.channel.id
      assert %LinkHub.Media.StoredFile{} = file_context.stored_file
      assert file_context.stored_file.id == ctx.stored_file.id
    end

    test "does not return contexts for a different channel", ctx do
      LinkHub.Media.FileContext
      |> Ash.Changeset.for_create(:create, %{
        context_type: :channel,
        stored_file_id: ctx.stored_file.id,
        channel_id: ctx.channel.id
      })
      |> Ash.create!()

      other_channel = Factory.create_channel!(ctx.workspace, ctx.user)

      results =
        LinkHub.Media.FileContext
        |> Ash.Query.for_read(:list_by_channel, %{channel_id: other_channel.id})
        |> Ash.read!()

      assert results == []
    end
  end

  describe "destroy action" do
    test "destroying a context does not destroy the stored file", ctx do
      file_context =
        LinkHub.Media.FileContext
        |> Ash.Changeset.for_create(:create, %{
          context_type: :message,
          stored_file_id: ctx.stored_file.id,
          message_id: ctx.message.id
        })
        |> Ash.create!()

      assert :ok =
               file_context
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy()

      # Verify the stored file still exists
      assert {:ok, stored_file} =
               LinkHub.Media.StoredFile
               |> Ash.get(ctx.stored_file.id)

      assert stored_file.id == ctx.stored_file.id
    end
  end

  describe "unique_file_message identity" do
    test "prevents duplicate stored_file + message combinations", ctx do
      LinkHub.Media.FileContext
      |> Ash.Changeset.for_create(:create, %{
        context_type: :message,
        stored_file_id: ctx.stored_file.id,
        message_id: ctx.message.id
      })
      |> Ash.create!()

      assert {:error, %Ash.Error.Invalid{}} =
               LinkHub.Media.FileContext
               |> Ash.Changeset.for_create(:create, %{
                 context_type: :message,
                 stored_file_id: ctx.stored_file.id,
                 message_id: ctx.message.id
               })
               |> Ash.create()
    end

    test "allows same file in different messages", ctx do
      other_message = Factory.send_message!(ctx.channel, ctx.user, "Another message")

      assert {:ok, _} =
               LinkHub.Media.FileContext
               |> Ash.Changeset.for_create(:create, %{
                 context_type: :message,
                 stored_file_id: ctx.stored_file.id,
                 message_id: ctx.message.id
               })
               |> Ash.create()

      assert {:ok, _} =
               LinkHub.Media.FileContext
               |> Ash.Changeset.for_create(:create, %{
                 context_type: :message,
                 stored_file_id: ctx.stored_file.id,
                 message_id: other_message.id
               })
               |> Ash.create()
    end
  end
end
