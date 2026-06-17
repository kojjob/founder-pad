defmodule FounderPad.Compliance.Storage do
  @moduledoc """
  Evidence object-storage seam. Implementations presign short-lived upload URLs so
  clients upload biometric/document evidence **directly to object storage** — the
  bytes never transit the app or the database.

  The adapter is swappable by config (`:evidence_storage`); the sandbox adapter is
  the default and contacts no external service.
  """

  @type presigned :: %{url: String.t(), expires_at: DateTime.t()}

  @callback presign_upload(
              storage_key :: String.t(),
              content_type :: String.t(),
              opts :: keyword()
            ) ::
              {:ok, presigned()} | {:error, term()}

  @doc "Presign an upload URL for `storage_key` via the configured adapter."
  @spec presign_upload(String.t(), String.t(), keyword()) :: {:ok, presigned()} | {:error, term()}
  def presign_upload(storage_key, content_type, opts \\ []) do
    adapter().presign_upload(storage_key, content_type, opts)
  end

  @doc "The configured storage adapter (sandbox by default)."
  def adapter do
    Application.get_env(:founder_pad, :evidence_storage, FounderPad.Compliance.Storage.Sandbox)
  end
end
