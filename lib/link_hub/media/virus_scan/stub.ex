defmodule LinkHub.Media.VirusScan.Stub do
  @moduledoc "Stub virus scanner for dev/test — always returns clean."
  @behaviour LinkHub.Media.VirusScan

  @impl true
  def scan(_file_path), do: {:ok, :clean}
end
