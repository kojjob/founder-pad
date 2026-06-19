defmodule FounderPad.Repo.Migrations.CreateConsentReceipts do
  @moduledoc """
  Creates the consent_receipts table for the GhanaTrust Compliance domain.

  (Snapshots for pre-existing boilerplate tables — incidents, agent_templates,
  user_totps, referrals — were backfilled at the same time; their tables already
  exist from earlier migrations, so this migration only creates consent_receipts.)
  """

  use Ecto.Migration

  def up do
    create table(:consent_receipts, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:external_subject_id, :text)
      add(:purpose, :text, null: false)
      add(:data_categories, {:array, :text}, null: false, default: [])
      add(:channel, :text, null: false, default: "api")
      add(:privacy_notice_version, :text)
      add(:accepted_at, :utc_datetime_usec, null: false)
      add(:ip_address, :text)
      add(:user_agent, :text)
      add(:device_fingerprint, :text)
      add(:retention_policy, :text)
      add(:status, :text, null: false, default: "active")
      add(:withdrawn_at, :utc_datetime_usec)
      add(:expires_at, :utc_datetime_usec)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(
        :organisation_id,
        references(:organisations,
          column: :id,
          name: "consent_receipts_organisation_id_fkey",
          type: :uuid,
          prefix: "public"
        ),
        null: false
      )
    end

    create(index(:consent_receipts, [:organisation_id, :inserted_at]))
    create(index(:consent_receipts, [:organisation_id, :status]))
  end

  def down do
    drop(constraint(:consent_receipts, "consent_receipts_organisation_id_fkey"))
    drop(table(:consent_receipts))
  end
end
