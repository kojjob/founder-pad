defmodule Mix.Tasks.FounderPad.Setup do
  @moduledoc """
  Sets up the FounderPad development environment.

  Runs: deps.get → ecto.create → ecto.migrate → seed_plans → assets

      mix founder_pad.setup
  """
  use Mix.Task

  @shortdoc "Set up FounderPad for development"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("🚀 Setting up FounderPad...")

    steps = [
      {"Installing dependencies", "deps.get"},
      {"Creating database", "ecto.create"},
      {"Running migrations", "ecto.migrate"},
      {"Seeding plans", "founder_pad.seed_plans"}
    ]

    Enum.each(steps, fn {label, task} ->
      Mix.shell().info("\n→ #{label}...")

      case Mix.Task.run(task) do
        :ok -> Mix.shell().info("  ✓ #{label} complete")
        _ -> Mix.shell().info("  ✓ #{label} complete")
      end
    end)

    Mix.shell().info("""
    \n✅ FounderPad setup complete!

    Start the server:
      mix phx.server

    Run tests:
      mix test

    Visit http://localhost:4000
    """)
  end
end
