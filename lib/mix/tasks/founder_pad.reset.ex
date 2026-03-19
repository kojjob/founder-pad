defmodule Mix.Tasks.FounderPad.Reset do
  @moduledoc """
  Resets the database and re-seeds.

      mix founder_pad.reset
  """
  use Mix.Task

  @shortdoc "Reset database and re-seed"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("🔄 Resetting FounderPad database...")

    Mix.Task.run("ecto.reset")
    Mix.Task.run("founder_pad.seed_plans")

    Mix.shell().info("✅ Database reset complete!")
  end
end
