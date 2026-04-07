defmodule LinkHub.Media.Storage.Local do
  @moduledoc """
  Local filesystem storage adapter for development.
  Stores files in priv/static/uploads and serves via Phoenix static.
  """

  @behaviour LinkHub.Media.Storage

  @impl true
  def presigned_upload_url(key, _opts) do
    base_url = LinkHubWeb.Endpoint.url()
    {:ok, "#{base_url}/api/uploads/local/#{key}"}
  end

  @impl true
  def presigned_download_url(key, _opts) do
    base_url = LinkHubWeb.Endpoint.url()
    {:ok, "#{base_url}/uploads/#{key}"}
  end

  @impl true
  def upload_file(key, local_path, _opts) do
    dest = Path.join(uploads_dir(), key)
    dest |> Path.dirname() |> File.mkdir_p!()
    File.cp!(local_path, dest)
    {:ok, key}
  end

  @impl true
  def delete_object(key, _opts) do
    path = Path.join(uploads_dir(), key)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def head_object(key, _opts) do
    path = Path.join(uploads_dir(), key)

    case File.stat(path) do
      {:ok, stat} ->
        {:ok, %{"content-length" => Integer.to_string(stat.size)}}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp uploads_dir do
    Application.app_dir(:link_hub, "priv/static/uploads")
  end
end
