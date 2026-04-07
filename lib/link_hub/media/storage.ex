defmodule LinkHub.Media.Storage do
  @moduledoc """
  Behaviour for file storage adapters.

  All storage operations go through this module — never call ExAws directly.
  Adapter is selected via config: `:link_hub, :storage_adapter`.
  """

  @type key :: String.t()
  @type opts :: keyword()

  @callback presigned_upload_url(key, opts) :: {:ok, String.t()} | {:error, term()}
  @callback presigned_download_url(key, opts) :: {:ok, String.t()} | {:error, term()}
  @callback upload_file(key, local_path :: String.t(), opts) :: {:ok, key} | {:error, term()}
  @callback delete_object(key, opts) :: :ok | {:error, term()}
  @callback head_object(key, opts) :: {:ok, map()} | {:error, :not_found} | {:error, term()}

  def adapter do
    Application.get_env(:link_hub, :storage_adapter, LinkHub.Media.Storage.S3)
  end

  def bucket do
    Application.get_env(:link_hub, :storage_bucket, "linkhub-uploads")
  end

  def presigned_upload_url(key, opts \\ []) do
    adapter().presigned_upload_url(key, opts)
  end

  def presigned_download_url(key, opts \\ []) do
    adapter().presigned_download_url(key, opts)
  end

  def upload_file(key, local_path, opts \\ []) do
    adapter().upload_file(key, local_path, opts)
  end

  def delete_object(key, opts \\ []) do
    adapter().delete_object(key, opts)
  end

  def head_object(key, opts \\ []) do
    adapter().head_object(key, opts)
  end
end
