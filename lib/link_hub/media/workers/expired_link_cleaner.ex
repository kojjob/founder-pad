defmodule LinkHub.Media.Workers.ExpiredLinkCleaner do
  @moduledoc """
  Oban cron worker that deactivates expired share links.
  Runs every hour by default.
  """
  use Oban.Worker, queue: :media, max_attempts: 3

  require Logger
  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    expired_links =
      LinkHub.Media.ShareLink
      |> Ash.Query.for_read(:list_expired)
      |> Ash.read!()

    count = length(expired_links)

    if count > 0 do
      Enum.each(expired_links, fn link ->
        link
        |> Ash.Changeset.for_update(:deactivate)
        |> Ash.update!()
      end)

      Logger.info("ExpiredLinkCleaner: deactivated #{count} expired share links")
    end

    :ok
  end
end
