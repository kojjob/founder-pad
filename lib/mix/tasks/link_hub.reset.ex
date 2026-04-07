defmodule Mix.Tasks.LinkHub.Reset do
  @moduledoc """
  Resets the database and re-seeds.

      mix link_hub.reset
  """
  use Mix.Task

  @shortdoc "Reset database and re-seed"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("🔄 Resetting LinkHub database...")

    Mix.Task.run("ecto.reset")
    Mix.Task.run("link_hub.seed_plans")

    Mix.shell().info("✅ Database reset complete!")
  end
end
