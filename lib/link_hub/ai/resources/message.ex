defmodule LinkHub.AI.Message do
  @moduledoc "Ash resource representing a message in an AI conversation."
  use Ash.Resource,
    domain: LinkHub.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("messages")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :role, :atom do
      constraints(one_of: [:user, :assistant, :system, :tool_result])
      allow_nil?(false)
      public?(true)
    end

    attribute :content, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute(:token_count, :integer, default: 0, public?: true)
    attribute(:cost_cents, :integer, default: 0, public?: true)
    attribute(:metadata, :map, default: %{}, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :conversation, LinkHub.AI.Conversation do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:role, :content, :token_count, :cost_cents, :metadata])
      argument(:conversation_id, :uuid, allow_nil?: false)
      change(manage_relationship(:conversation_id, :conversation, type: :append))
    end
  end
end
