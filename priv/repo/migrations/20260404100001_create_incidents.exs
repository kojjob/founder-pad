defmodule FounderPad.Repo.Migrations.CreateIncidents do
  use Ecto.Migration

  def change do
    create table(:incidents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "investigating"
      add :severity, :string, null: false, default: "minor"
      add :affected_components, {:array, :string}, default: []
      add :resolved_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:incidents, [:status])
    create index(:incidents, [:inserted_at])
  end
end
