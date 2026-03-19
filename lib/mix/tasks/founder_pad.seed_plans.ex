defmodule Mix.Tasks.FounderPad.SeedPlans do
  @moduledoc "Seeds billing plans from config/plans.exs"
  use Mix.Task

  @shortdoc "Seed billing plans"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    plans = Application.get_env(:founder_pad, :plans, [])

    Enum.each(plans, fn plan_attrs ->
      require Ash.Query

      case FounderPad.Billing.Plan
           |> Ash.Query.filter(slug: plan_attrs.slug)
           |> Ash.read_one() do
        {:ok, nil} ->
          FounderPad.Billing.Plan
          |> Ash.Changeset.for_create(:create, plan_attrs)
          |> Ash.create!()

          Mix.shell().info("Created plan: #{plan_attrs.name}")

        {:ok, _existing} ->
          Mix.shell().info("Plan already exists: #{plan_attrs.name}")

        {:error, error} ->
          Mix.shell().error("Error checking plan #{plan_attrs.name}: #{inspect(error)}")
      end
    end)
  end
end
