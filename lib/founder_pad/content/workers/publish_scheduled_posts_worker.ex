defmodule FounderPad.Content.Workers.PublishScheduledPostsWorker do
  @moduledoc "Oban cron worker that publishes scheduled posts when their scheduled_at time has passed."
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(_job) do
    FounderPad.Content.Post
    |> Ash.Query.for_read(:scheduled_ready)
    |> Ash.read!()
    |> Enum.each(fn post ->
      post
      |> Ash.Changeset.for_update(:publish, %{})
      |> Ash.update!()
    end)

    :ok
  end
end
