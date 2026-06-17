defmodule FounderPad.Compliance.Storage.Sandbox do
  @moduledoc """
  Deterministic sandbox storage adapter. Returns a short-lived fake upload URL that
  references the storage key — no real object storage is involved. Used until a real
  S3/GCS adapter is configured.
  """
  @behaviour FounderPad.Compliance.Storage

  @ttl_seconds 600

  @impl true
  def presign_upload(storage_key, _content_type, opts \\ []) do
    ttl = Keyword.get(opts, :ttl_seconds, @ttl_seconds)
    expires_at = DateTime.utc_now() |> DateTime.add(ttl, :second)

    url =
      "https://sandbox-uploads.ghanatrust.local/#{storage_key}" <>
        "?expires=#{DateTime.to_unix(expires_at)}"

    {:ok, %{url: url, expires_at: expires_at}}
  end
end
