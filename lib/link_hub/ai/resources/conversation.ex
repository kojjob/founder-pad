defmodule LinkHub.AI.Conversation do
  @moduledoc "Ash resource representing a conversation with an AI agent."
  use Ash.Resource,
    domain: LinkHub.AI,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("conversations")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:title, :string, public?: true)

    attribute :status, :atom do
      constraints(one_of: [:active, :archived])
      default(:active)
      allow_nil?(false)
      public?(true)
    end

    attribute(:metadata, :map, default: %{}, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :agent, LinkHub.AI.Agent do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :workspace, LinkHub.Accounts.Workspace do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :user, LinkHub.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    has_many(:messages, LinkHub.AI.Message)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:title, :status, :metadata])
      argument(:agent_id, :uuid, allow_nil?: false)
      argument(:workspace_id, :uuid, allow_nil?: false)
      argument(:user_id, :uuid, allow_nil?: false)
      change(manage_relationship(:agent_id, :agent, type: :append))
      change(manage_relationship(:workspace_id, :workspace, type: :append))
      change(manage_relationship(:user_id, :user, type: :append))
    end

    update :archive do
      accept([])
      change(set_attribute(:status, :archived))
    end
  end
end
