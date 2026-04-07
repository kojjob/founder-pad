defmodule FounderPad.Repo.Migrations.CreateUserTotps do
  use Ecto.Migration

  def change do
    create table(:user_totps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :secret, :string, null: false
      add :enabled, :boolean, null: false, default: false
      add :backup_codes, {:array, :string}, default: []
      add :last_used_at, :utc_datetime_usec
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_totps, [:user_id])
  end
end
