defmodule LinkHubWeb.UploadController do
  @moduledoc """
  Handles presigned URL generation for file uploads and download URL retrieval.

  Flow:
  1. Client calls `initiate` to get a presigned upload URL and a file record ID
  2. Client uploads the file directly to storage using the presigned URL
  3. Client calls `complete` to trigger async file processing (virus scan, thumbnails)
  4. Client calls `get_url` to retrieve a presigned download URL
  """
  use LinkHubWeb, :controller

  require Logger

  plug :require_authenticated_user

  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Authentication required"})
      |> halt()
    end
  end

  def initiate(
        conn,
        %{"filename" => filename, "content_type" => content_type, "size_bytes" => size_bytes} =
          params
      ) do
    user = conn.assigns[:current_user]
    workspace_id = params["workspace_id"]

    storage_key = "uploads/#{Ash.UUID.generate()}/#{filename}"

    case LinkHub.Media.Storage.presigned_upload_url(storage_key, content_type: content_type) do
      {:ok, upload_url} ->
        case LinkHub.Media.StoredFile
             |> Ash.Changeset.for_create(:upload, %{
               filename: filename,
               content_type: content_type,
               size_bytes: size_bytes,
               storage_key: storage_key,
               workspace_id: workspace_id,
               uploader_id: user.id
             })
             |> Ash.create() do
          {:ok, stored_file} ->
            json(conn, %{
              upload_url: upload_url,
              storage_key: storage_key,
              file_id: stored_file.id
            })

          {:error, reason} ->
            Logger.error(
              "UploadController.initiate: failed to create StoredFile: #{inspect(reason)}"
            )

            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to create file record"})
        end

      {:error, reason} ->
        Logger.error(
          "UploadController.initiate: presigned URL generation failed: #{inspect(reason)}"
        )

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to generate upload URL"})
    end
  end

  def complete(conn, %{"file_id" => file_id}) do
    case Ash.get(LinkHub.Media.StoredFile, file_id) do
      {:ok, _file} ->
        %{"file_id" => file_id}
        |> LinkHub.Media.Workers.FileProcessor.new()
        |> Oban.insert!()

        json(conn, %{status: "processing", file_id: file_id})

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "File not found"})
    end
  end

  def get_url(conn, %{"file_id" => file_id}) do
    case Ash.get(LinkHub.Media.StoredFile, file_id) do
      {:ok, file} ->
        case LinkHub.Media.Storage.presigned_download_url(file.storage_key) do
          {:ok, url} ->
            json(conn, %{url: url, filename: file.filename, content_type: file.content_type})

          {:error, reason} ->
            Logger.error(
              "UploadController.get_url: download URL generation failed: #{inspect(reason)}"
            )

            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to generate download URL"})
        end

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "File not found"})
    end
  end
end
