defmodule LinkHub.Analytics.Workers.GscSyncWorker do
  @moduledoc """
  Oban worker that fetches Google Search Console data.
  Scheduled daily per org that has GSC configured.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"workspace_id" => org_id}}) do
    Logger.info("GSC sync starting for org #{org_id}")

    {:ok, data} = fetch_gsc_data(org_id)

    Enum.each(data, fn row ->
      LinkHub.Analytics.SearchConsoleData
      |> Ash.Changeset.for_create(:create, Map.put(row, :workspace_id, org_id))
      |> Ash.create()
    end)

    Logger.info("GSC sync completed for org #{org_id}: #{length(data)} rows")
    :ok
  end

  defp fetch_gsc_data(_org_id) do
    case Application.get_env(:link_hub, :gsc_credentials) do
      nil ->
        Logger.debug("GSC not configured, skipping sync")
        {:ok, []}

      _credentials ->
        # GSC API integration pending — requires OAuth2 setup and service account key.
        # See: https://developers.google.com/webmaster-tools/v1/api_reference_index
        Logger.info("GSC credentials present but API integration not yet implemented")
        {:ok, []}
    end
  end
end
