defmodule LinkHub.Media.StoredFileTest do
  use LinkHub.DataCase, async: true

  alias LinkHub.Factory

  require Ash.Query

  setup do
    workspace = Factory.create_workspace!()
    user = Factory.create_user!()
    Factory.create_membership!(user, workspace)
    %{workspace: workspace, user: user}
  end

  describe "upload action" do
    test "creates a stored file with pending status", %{workspace: workspace, user: user} do
      file = Factory.create_stored_file!(workspace, user)

      assert file.filename =~ "test-file-"
      assert file.content_type == "image/png"
      assert file.size_bytes == 1_048_576
      assert file.status == :pending
      assert file.virus_scan_status == :pending
      assert file.metadata == %{}
      assert file.workspace_id == workspace.id
      assert file.uploader_id == user.id
    end

    test "requires filename, content_type, size_bytes, storage_key", %{
      workspace: workspace,
      user: user
    } do
      assert_raise Ash.Error.Invalid, fn ->
        LinkHub.Media.StoredFile
        |> Ash.Changeset.for_create(:upload, %{
          workspace_id: workspace.id,
          uploader_id: user.id
        })
        |> Ash.create!()
      end
    end

    test "stores content hash and metadata", %{workspace: workspace, user: user} do
      file =
        Factory.create_stored_file!(workspace, user, %{
          content_hash: "sha256:abc123def456",
          metadata: %{"width" => 1920, "height" => 1080}
        })

      assert file.content_hash == "sha256:abc123def456"
      assert file.metadata == %{"width" => 1920, "height" => 1080}
    end
  end

  describe "status transitions" do
    test "mark_processing transitions from pending", %{workspace: workspace, user: user} do
      file = Factory.create_stored_file!(workspace, user)
      assert file.status == :pending

      updated =
        file
        |> Ash.Changeset.for_update(:mark_processing)
        |> Ash.update!()

      assert updated.status == :processing
    end

    test "mark_ready sets status and optional thumbnail", %{workspace: workspace, user: user} do
      file = Factory.create_stored_file!(workspace, user)

      updated =
        file
        |> Ash.Changeset.for_update(:mark_ready, %{
          thumbnail_key: "thumbnails/#{file.id}_thumb.jpg",
          metadata: %{"width" => 800, "height" => 600}
        })
        |> Ash.update!()

      assert updated.status == :ready
      assert updated.thumbnail_key =~ "thumb.jpg"
      assert updated.metadata["width"] == 800
    end

    test "mark_failed sets status with error metadata", %{workspace: workspace, user: user} do
      file = Factory.create_stored_file!(workspace, user)

      updated =
        file
        |> Ash.Changeset.for_update(:mark_failed, %{
          metadata: %{"error" => "virus detected"}
        })
        |> Ash.update!()

      assert updated.status == :failed
      assert updated.metadata["error"] == "virus detected"
    end
  end

  describe "virus scan" do
    test "set_virus_scan updates scan status", %{workspace: workspace, user: user} do
      file = Factory.create_stored_file!(workspace, user)
      assert file.virus_scan_status == :pending

      updated =
        file
        |> Ash.Changeset.for_update(:set_virus_scan, %{scan_result: :clean})
        |> Ash.update!()

      assert updated.virus_scan_status == :clean
    end
  end

  describe "read actions" do
    test "list_by_workspace returns files for workspace", %{workspace: workspace, user: user} do
      Factory.create_stored_file!(workspace, user)
      Factory.create_stored_file!(workspace, user)

      other_workspace = Factory.create_workspace!()
      Factory.create_stored_file!(other_workspace, user)

      files =
        LinkHub.Media.StoredFile
        |> Ash.Query.for_read(:list_by_workspace, %{workspace_id: workspace.id})
        |> Ash.read!()

      assert length(files) == 2
    end

    test "list_ready_by_workspace only returns ready files", %{
      workspace: workspace,
      user: user
    } do
      pending_file = Factory.create_stored_file!(workspace, user)

      ready_file = Factory.create_stored_file!(workspace, user)

      ready_file
      |> Ash.Changeset.for_update(:mark_ready, %{})
      |> Ash.update!()

      # pending_file should not appear
      _ = pending_file

      files =
        LinkHub.Media.StoredFile
        |> Ash.Query.for_read(:list_ready_by_workspace, %{workspace_id: workspace.id})
        |> Ash.read!()

      assert length(files) == 1
      assert hd(files).status == :ready
    end

    test "search finds files by name", %{workspace: workspace, user: user} do
      Factory.create_stored_file!(workspace, user, %{filename: "quarterly-report.pdf"})
      Factory.create_stored_file!(workspace, user, %{filename: "team-photo.jpg"})

      results =
        LinkHub.Media.StoredFile
        |> Ash.Query.for_read(:search, %{workspace_id: workspace.id, query: "report"})
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).filename == "quarterly-report.pdf"
    end
  end

  describe "calculations" do
    test "is_image returns true for image content types", %{workspace: workspace, user: user} do
      file =
        Factory.create_stored_file!(workspace, user, %{content_type: "image/jpeg"})
        |> Ash.load!(:is_image)

      assert file.is_image == true
    end

    test "is_image returns false for non-image types", %{workspace: workspace, user: user} do
      file =
        Factory.create_stored_file!(workspace, user, %{content_type: "application/pdf"})
        |> Ash.load!(:is_image)

      assert file.is_image == false
    end
  end
end
