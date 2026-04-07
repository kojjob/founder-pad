defmodule LinkHub.Media.Workers.FileProcessorTest do
  use LinkHub.DataCase, async: false
  use Oban.Testing, repo: LinkHub.Repo

  alias LinkHub.Factory
  alias LinkHub.Media.Workers.FileProcessor

  setup do
    workspace = Factory.create_workspace!()
    user = Factory.create_user!()
    Factory.create_membership!(user, workspace)
    %{workspace: workspace, user: user}
  end

  describe "perform/1" do
    test "processes a file and marks it ready", %{workspace: workspace, user: user} do
      file = Factory.create_stored_file!(workspace, user)
      assert file.status == :pending

      assert :ok = perform_job(FileProcessor, %{"file_id" => file.id})

      updated = Ash.get!(LinkHub.Media.StoredFile, file.id)
      assert updated.status == :ready
      assert updated.virus_scan_status == :clean
    end

    test "handles missing file gracefully" do
      missing_id = Ash.UUID.generate()
      assert :ok = perform_job(FileProcessor, %{"file_id" => missing_id})
    end

    test "processes image files with thumbnail key", %{workspace: workspace, user: user} do
      file =
        Factory.create_stored_file!(workspace, user, %{
          content_type: "image/jpeg",
          filename: "photo.jpg"
        })

      assert :ok = perform_job(FileProcessor, %{"file_id" => file.id})

      updated = Ash.get!(LinkHub.Media.StoredFile, file.id)
      assert updated.status == :ready
      assert updated.thumbnail_key =~ "thumb.jpg"
    end

    test "skips thumbnail for non-image files", %{workspace: workspace, user: user} do
      file =
        Factory.create_stored_file!(workspace, user, %{
          content_type: "application/pdf",
          filename: "report.pdf"
        })

      assert :ok = perform_job(FileProcessor, %{"file_id" => file.id})

      updated = Ash.get!(LinkHub.Media.StoredFile, file.id)
      assert updated.status == :ready
      assert is_nil(updated.thumbnail_key)
    end
  end

  describe "job enqueueing" do
    test "can be enqueued with file_id", %{workspace: workspace, user: user} do
      file = Factory.create_stored_file!(workspace, user)

      assert_enqueue(FileProcessor, %{"file_id" => file.id})
    end
  end

  defp assert_enqueue(worker, args) do
    assert {:ok, _} = Oban.insert(worker.new(args))
    assert_enqueued(worker: worker, args: args)
  end
end
