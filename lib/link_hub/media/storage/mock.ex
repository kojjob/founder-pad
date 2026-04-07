defmodule LinkHub.Media.Storage.Mock do
  @moduledoc """
  Mock storage adapter for tests.
  Returns predictable URLs without touching the filesystem or network.
  """

  @behaviour LinkHub.Media.Storage

  @impl true
  def presigned_upload_url(key, _opts) do
    {:ok, "https://s3.mock.example.com/uploads/#{key}?presigned=put"}
  end

  @impl true
  def presigned_download_url(key, _opts) do
    {:ok, "https://s3.mock.example.com/uploads/#{key}?presigned=get"}
  end

  @impl true
  def upload_file(key, _local_path, _opts) do
    {:ok, key}
  end

  @impl true
  def delete_object(_key, _opts) do
    :ok
  end

  @impl true
  def head_object(_key, _opts) do
    {:ok, %{"content-length" => "1024"}}
  end
end
