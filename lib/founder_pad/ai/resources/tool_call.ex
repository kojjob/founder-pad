defmodule FounderPad.AI.ToolCall do
  use Ash.Resource,
    domain: FounderPad.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "tool_calls"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :tool_name, :string do
      allow_nil? false
      public? true
    end

    attribute :input, :map, default: %{}, public?: true
    attribute :output, :map, public?: true

    attribute :status, :atom do
      constraints one_of: [:pending, :running, :completed, :failed]
      default :pending
      allow_nil? false
      public? true
    end

    attribute :duration_ms, :integer, public?: true
    attribute :error, :string, public?: true

    timestamps()
  end

  relationships do
    belongs_to :message, FounderPad.AI.Message do
      allow_nil? false
      public? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:tool_name, :input, :status]
      argument :message_id, :uuid, allow_nil?: false
      change manage_relationship(:message_id, :message, type: :append)
    end

    update :complete do
      accept [:output, :duration_ms]
      change set_attribute(:status, :completed)
    end

    update :fail do
      accept [:error, :duration_ms]
      change set_attribute(:status, :failed)
    end
  end
end
