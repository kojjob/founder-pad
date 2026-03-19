defmodule FounderPad.Analytics.Workers.GscSyncWorker do
  @moduledoc """
  Oban worker that fetches Google Search Console data.
  Scheduled daily per org that has GSC configured.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"organisation_id" => org_id}}) do
    Logger.info("GSC sync starting for org #{org_id}")

    case fetch_gsc_data(org_id) do
      {:ok, data} ->
        Enum.each(data, fn row ->
          FounderPad.Analytics.SearchConsoleData
          |> Ash.Changeset.for_create(:create, Map.put(row, :organisation_id, org_id))
          |> Ash.create()
        end)

        Logger.info("GSC sync completed for org #{org_id}: #{length(data)} rows")
        :ok

      {:error, reason} ->
        Logger.error("GSC sync failed for org #{org_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_gsc_data(_org_id) do
    # Stub: returns empty data until GSC API credentials are configured
    gsc_configured? = Application.get_env(:founder_pad, :gsc_credentials) != nil

    if gsc_configured? do
      # TODO: Call actual Google Search Console API
      {:ok, []}
    else
      Logger.debug("GSC not configured, skipping sync")
      {:ok, []}
    end
  end
end
