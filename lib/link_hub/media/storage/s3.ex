defmodule LinkHub.Media.Storage.S3 do
  @moduledoc """
  S3 storage adapter for production use.
  """

  @behaviour LinkHub.Media.Storage

  @impl true
  def presigned_upload_url(key, opts) do
    bucket = LinkHub.Media.Storage.bucket()
    expires_in = Keyword.get(opts, :expires_in, 900)
    content_type = Keyword.get(opts, :content_type)

    headers =
      if content_type, do: [{"content-type", content_type}], else: []

    ExAws.Config.new(:s3)
    |> ExAws.S3.presigned_url(:put, bucket, key,
      expires_in: expires_in,
      headers: headers
    )
  end

  @impl true
  def presigned_download_url(key, opts) do
    bucket = LinkHub.Media.Storage.bucket()
    expires_in = Keyword.get(opts, :expires_in, 3600)
    filename = Keyword.get(opts, :filename)

    query_params =
      if filename do
        [{"response-content-disposition", "attachment; filename=\"#{filename}\""}]
      else
        []
      end

    ExAws.Config.new(:s3)
    |> ExAws.S3.presigned_url(:get, bucket, key,
      expires_in: expires_in,
      query_params: query_params
    )
  end

  @impl true
  def upload_file(key, local_path, opts) do
    bucket = LinkHub.Media.Storage.bucket()
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    local_path
    |> File.stream!([], 5 * 1024 * 1024)
    |> ExAws.S3.upload(bucket, key, content_type: content_type)
    |> ExAws.request()
    |> case do
      {:ok, _} -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_object(key, _opts) do
    bucket = LinkHub.Media.Storage.bucket()

    case ExAws.S3.delete_object(bucket, key) |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def head_object(key, _opts) do
    bucket = LinkHub.Media.Storage.bucket()

    case ExAws.S3.head_object(bucket, key) |> ExAws.request() do
      {:ok, %{headers: headers}} ->
        {:ok, headers_to_map(headers)}

      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {k, v}, acc ->
      Map.put(acc, String.downcase(k), v)
    end)
  end
end
