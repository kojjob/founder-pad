defmodule LinkHubWeb.UploadControllerTest do
  use LinkHubWeb.ConnCase, async: true
  use Oban.Testing, repo: LinkHub.Repo

  import LinkHub.Factory
  import LinkHub.LiveViewHelpers

  describe "POST /api/uploads/initiate" do
    test "creates a StoredFile and returns upload_url + file_id", %{conn: conn} do
      {conn, _user, workspace} = setup_authenticated_user(conn)

      params = %{
        "filename" => "report.pdf",
        "content_type" => "application/pdf",
        "size_bytes" => 2_048_000,
        "workspace_id" => workspace.id
      }

      conn = post(conn, "/api/uploads/initiate", params)

      assert %{
               "upload_url" => upload_url,
               "storage_key" => storage_key,
               "file_id" => file_id
             } = json_response(conn, 200)

      assert String.contains?(upload_url, "presigned=put")
      assert String.starts_with?(storage_key, "uploads/")
      assert String.ends_with?(storage_key, "/report.pdf")

      # Verify the StoredFile was persisted
      {:ok, file} = Ash.get(LinkHub.Media.StoredFile, file_id)
      assert file.filename == "report.pdf"
      assert file.content_type == "application/pdf"
      assert file.size_bytes == 2_048_000
      assert file.status == :pending
    end

    test "returns 401-level error when not authenticated", %{conn: conn} do
      params = %{
        "filename" => "report.pdf",
        "content_type" => "application/pdf",
        "size_bytes" => 1024,
        "workspace_id" => Ash.UUID.generate()
      }

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> post("/api/uploads/initiate", params)

      assert json_response(conn, 401)["error"] == "Authentication required"
    end
  end

  describe "POST /api/uploads/complete" do
    test "enqueues a FileProcessor job for the given file", %{conn: conn} do
      {conn, user, workspace} = setup_authenticated_user(conn)
      file = create_stored_file!(workspace, user)

      conn = post(conn, "/api/uploads/complete", %{"file_id" => file.id})

      assert %{"status" => "processing", "file_id" => file_id} = json_response(conn, 200)
      assert file_id == file.id

      assert_enqueued(worker: LinkHub.Media.Workers.FileProcessor, args: %{"file_id" => file.id})
    end

    test "returns 404 for nonexistent file_id", %{conn: conn} do
      {conn, _user, _workspace} = setup_authenticated_user(conn)

      conn = post(conn, "/api/uploads/complete", %{"file_id" => Ash.UUID.generate()})

      assert json_response(conn, 404)["error"] == "File not found"
    end
  end

  describe "GET /api/uploads/:file_id/url" do
    test "returns a presigned download URL for an existing file", %{conn: conn} do
      {conn, user, workspace} = setup_authenticated_user(conn)

      file =
        create_stored_file!(workspace, user, filename: "photo.png", content_type: "image/png")

      conn = get(conn, "/api/uploads/#{file.id}/url")

      assert %{
               "url" => url,
               "filename" => "photo.png",
               "content_type" => "image/png"
             } = json_response(conn, 200)

      assert String.contains?(url, "presigned=get")
    end

    test "returns 404 for nonexistent file", %{conn: conn} do
      {conn, _user, _workspace} = setup_authenticated_user(conn)

      conn = get(conn, "/api/uploads/#{Ash.UUID.generate()}/url")

      assert json_response(conn, 404)["error"] == "File not found"
    end
  end
end
