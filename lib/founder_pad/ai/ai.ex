defmodule FounderPad.AI do
  use Ash.Domain

  resources do
    resource FounderPad.AI.Agent do
      define :create_agent, action: :create
      define :list_agents, action: :read
      define :get_agent, action: :read, get_by: [:id]
    end

    resource FounderPad.AI.Conversation do
      define :create_conversation, action: :create
      define :list_conversations, action: :read
      define :get_conversation, action: :read, get_by: [:id]
    end

    resource FounderPad.AI.Message do
      define :create_message, action: :create
      define :list_messages, action: :read
    end

    resource FounderPad.AI.ToolCall do
      define :create_tool_call, action: :create
      define :list_tool_calls, action: :read
    end

    resource FounderPad.AI.AgentTemplate do
      define :create_agent_template, action: :create
      define :list_agent_templates, action: :read
      define :get_agent_template, action: :read, get_by: [:id]
      define :list_featured_templates, action: :featured
      define :list_templates_by_category, action: :by_category, args: [:category]
    end
  end
end
