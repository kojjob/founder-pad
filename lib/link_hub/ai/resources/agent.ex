defmodule LinkHub.AI.Agent do
  @moduledoc "Ash resource representing an AI agent."
  use Ash.Resource,
    domain: LinkHub.AI,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table("agents")
    repo(LinkHub.Repo)
  end

  json_api do
    type("agent")

    routes do
      base("/agents")
      index(:read)
      get(:read)
    end
  end

  graphql do
    type(:agent)

    queries do
      list(:list_agents, :read)
      get(:get_agent, :read)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute(:description, :string, public?: true)

    attribute :system_prompt, :string do
      allow_nil?(false)
      default("You are a helpful assistant.")
      public?(true)
    end

    attribute :model, :string do
      allow_nil?(false)
      default("claude-sonnet-4-20250514")
      public?(true)
    end

    attribute :provider, :atom do
      constraints(one_of: [:anthropic, :openai])
      default(:anthropic)
      allow_nil?(false)
      public?(true)
    end

    attribute :tools, {:array, :map} do
      default([])
      public?(true)
    end

    attribute(:temperature, :float, default: 0.7, public?: true)
    attribute(:max_tokens, :integer, default: 4096, public?: true)
    attribute(:active, :boolean, default: true, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :workspace, LinkHub.Accounts.Workspace do
      allow_nil?(false)
      public?(true)
    end

    has_many(:conversations, LinkHub.AI.Conversation)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :name,
        :description,
        :system_prompt,
        :model,
        :provider,
        :tools,
        :temperature,
        :max_tokens,
        :active
      ])

      argument(:workspace_id, :uuid, allow_nil?: false)
      change(manage_relationship(:workspace_id, :workspace, type: :append))
    end

    update :update do
      accept([
        :name,
        :description,
        :system_prompt,
        :model,
        :provider,
        :tools,
        :temperature,
        :max_tokens,
        :active
      ])
    end
  end
end
