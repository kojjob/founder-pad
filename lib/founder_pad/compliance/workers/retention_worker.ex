defmodule FounderPad.Compliance.Workers.RetentionWorker do
  @moduledoc "Oban cron worker that runs the compliance data-retention sweep daily."
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(_job) do
    _counts = FounderPad.Compliance.Retention.run()
    :ok
  end
end
