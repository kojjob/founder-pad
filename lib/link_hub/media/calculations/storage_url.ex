defmodule LinkHub.Media.Calculations.StorageUrl do
  @moduledoc "Ash calculation that generates presigned download URLs via the Storage adapter."
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [:storage_key]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      case LinkHub.Media.Storage.presigned_download_url(record.storage_key) do
        {:ok, url} -> url
        {:error, _} -> nil
      end
    end)
  end
end
