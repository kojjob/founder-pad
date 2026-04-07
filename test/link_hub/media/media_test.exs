defmodule LinkHub.MediaTest do
  use LinkHub.DataCase, async: true

  alias LinkHub.Factory

  require Ash.Query

  setup do
    {workspace, user, channel} = Factory.create_messaging_context!()
    %{workspace: workspace, user: user, channel: channel}
  end

  describe "FileAttachment" do
    test "creates a file attachment for a message", %{
      workspace: workspace,
      user: user,
      channel: channel
    } do
      message = Factory.send_message!(channel, user, "Check this file")

      attachment =
        LinkHub.Media.FileAttachment
        |> Ash.Changeset.for_create(:create, %{
          filename: "design.png",
          content_type: "image/png",
          size_bytes: 1_048_576,
          storage_path: "abc123.png",
          workspace_id: workspace.id,
          uploader_id: user.id,
          message_id: message.id
        })
        |> Ash.create!()

      assert attachment.filename == "design.png"
      assert attachment.content_type == "image/png"
      assert attachment.size_bytes == 1_048_576
      assert attachment.workspace_id == workspace.id
      assert attachment.message_id == message.id
    end

    test "creates an attachment without a message", %{workspace: workspace, user: user} do
      attachment =
        LinkHub.Media.FileAttachment
        |> Ash.Changeset.for_create(:create, %{
          filename: "notes.pdf",
          content_type: "application/pdf",
          size_bytes: 512_000,
          storage_path: "def456.pdf",
          workspace_id: workspace.id,
          uploader_id: user.id
        })
        |> Ash.create!()

      assert attachment.filename == "notes.pdf"
      assert is_nil(attachment.message_id)
    end

    test "lists attachments for a message", %{workspace: workspace, user: user, channel: channel} do
      message = Factory.send_message!(channel, user, "Files here")

      for i <- 1..3 do
        LinkHub.Media.FileAttachment
        |> Ash.Changeset.for_create(:create, %{
          filename: "file#{i}.txt",
          content_type: "text/plain",
          size_bytes: 100 * i,
          storage_path: "file#{i}_#{System.unique_integer([:positive])}.txt",
          workspace_id: workspace.id,
          uploader_id: user.id,
          message_id: message.id
        })
        |> Ash.create!()
      end

      attachments =
        LinkHub.Media.FileAttachment
        |> Ash.Query.for_read(:list_by_message, %{message_id: message.id})
        |> Ash.read!()

      assert length(attachments) == 3
    end

    test "searches files by filename", %{workspace: workspace, user: user} do
      LinkHub.Media.FileAttachment
      |> Ash.Changeset.for_create(:create, %{
        filename: "quarterly-report.pdf",
        content_type: "application/pdf",
        size_bytes: 2_000_000,
        storage_path: "report_#{System.unique_integer([:positive])}.pdf",
        workspace_id: workspace.id,
        uploader_id: user.id
      })
      |> Ash.create!()

      LinkHub.Media.FileAttachment
      |> Ash.Changeset.for_create(:create, %{
        filename: "team-photo.jpg",
        content_type: "image/jpeg",
        size_bytes: 500_000,
        storage_path: "photo_#{System.unique_integer([:positive])}.jpg",
        workspace_id: workspace.id,
        uploader_id: user.id
      })
      |> Ash.create!()

      results =
        LinkHub.Media.FileAttachment
        |> Ash.Query.for_read(:search, %{workspace_id: workspace.id, query: "report"})
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).filename == "quarterly-report.pdf"
    end
  end

  describe "Message search" do
    test "searches messages by body content", %{user: user, channel: channel} do
      Factory.send_message!(channel, user, "Let's discuss the API design")
      Factory.send_message!(channel, user, "Meeting at 3pm")
      Factory.send_message!(channel, user, "The API endpoint is ready")

      results =
        LinkHub.Messaging.Message
        |> Ash.Query.for_read(:search, %{channel_id: channel.id, query: "API"})
        |> Ash.read!()

      assert length(results) == 2
    end

    test "search excludes deleted messages", %{user: user, channel: channel} do
      msg = Factory.send_message!(channel, user, "Delete this API note")

      msg
      |> Ash.Changeset.for_update(:soft_delete)
      |> Ash.update!()

      results =
        LinkHub.Messaging.Message
        |> Ash.Query.for_read(:search, %{channel_id: channel.id, query: "API"})
        |> Ash.read!()

      assert results == []
    end
  end
end
