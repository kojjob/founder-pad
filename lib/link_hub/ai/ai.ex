defmodule LinkHub.AI do
  @moduledoc "Ash domain for AI agents, conversations, messages, and tool calls."
  use Ash.Domain

  resources do
    resource LinkHub.AI.Agent do
      define(:create_agent, action: :create)
      define(:list_agents, action: :read)
      define(:get_agent, action: :read, get_by: [:id])
    end

    resource LinkHub.AI.Conversation do
      define(:create_conversation, action: :create)
      define(:list_conversations, action: :read)
      define(:get_conversation, action: :read, get_by: [:id])
    end

    resource LinkHub.AI.Message do
      define(:create_message, action: :create)
      define(:list_messages, action: :read)
    end

    resource LinkHub.AI.ToolCall do
      define(:create_tool_call, action: :create)
      define(:list_tool_calls, action: :read)
    end
  end
end
