defmodule FounderPad.Repo.Migrations.CreateReferrals do
  @moduledoc """
  Creates the referrals table.
  """

  use Ecto.Migration

  def up do
    create table(:referrals, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :code, :text, null: false
      add :status, :text, null: false, default: "pending"
      add :reward_type, :text, default: "credit"
      add :reward_amount_cents, :bigint, default: 500
      add :completed_at, :utc_datetime_usec

      add :referrer_id, references(:users, type: :uuid, column: :id), null: false
      add :referred_id, references(:users, type: :uuid, column: :id)

      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create unique_index(:referrals, [:code], name: "referrals_unique_code_index")
    create index(:referrals, [:referrer_id])
    create index(:referrals, [:referred_id])
  end

  def down do
    drop_if_exists table(:referrals)
  end
end
