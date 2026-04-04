defmodule FounderPad.Repo.Migrations.CreateAgentTemplates do
  @moduledoc """
  Creates the agent_templates table.
  """

  use Ecto.Migration

  def up do
    create table(:agent_templates, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :description, :text
      add :category, :text
      add :system_prompt, :text
      add :model, :text, default: "claude-sonnet-4-20250514"
      add :provider, :text, default: "anthropic"
      add :icon, :text, default: "smart_toy"
      add :featured, :boolean, default: false
      add :use_count, :bigint, default: 0

      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:agent_templates, [:category])
    create index(:agent_templates, [:featured])
  end

  def down do
    drop_if_exists table(:agent_templates)
  end
end
