defmodule FounderPad.Privacy.Workers.HardDeleteWorker do
  @moduledoc "Oban cron worker that permanently deletes user accounts after the 30-day grace period."
  use Oban.Worker, queue: :default, max_attempts: 3

  require Ash.Query

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    FounderPad.Privacy.DeletionRequest
    |> Ash.Query.filter(status == :confirmed and hard_delete_after <= ^now)
    |> Ash.read!()
    |> Enum.each(fn request ->
      request
      |> Ash.Changeset.for_update(:execute_soft_delete, %{})
      |> Ash.update!()
    end)

    :ok
  end
end
