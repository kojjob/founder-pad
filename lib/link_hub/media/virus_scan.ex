defmodule LinkHub.Media.VirusScan do
  @moduledoc """
  Behaviour for virus scanning adapters.
  Production: ClamAV integration. Dev/Test: stub that returns :clean.
  """

  @callback scan(file_path :: String.t()) :: {:ok, :clean} | {:ok, :infected} | {:error, term()}

  def adapter do
    Application.get_env(:link_hub, :virus_scan_adapter, __MODULE__.Stub)
  end

  def scan(file_path) do
    adapter().scan(file_path)
  end
end
