defmodule FounderPad.AI.Workers.AgentRunner do
  @moduledoc """
  Oban worker that runs AI agent conversations.
  Broadcasts streaming results via PubSub.
  """
  use Oban.Worker, queue: :ai, max_attempts: 3

  require Logger
  require Ash.Query

  alias FounderPad.AI

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "conversation_id" => conversation_id,
          "message_content" => message_content,
          "organisation_id" => organisation_id
        }
      }) do
    with {:ok, conversation} <- Ash.get(AI.Conversation, conversation_id, load: [:agent]),
         {:ok, _user_msg} <- create_message(conversation_id, :user, message_content),
         provider <- get_provider(conversation.agent.provider),
         messages <- build_messages(conversation_id, message_content),
         {:ok, response} <- provider.chat(messages, agent_opts(conversation.agent)) do
      # Save assistant message
      {:ok, _assistant_msg} = create_message(conversation_id, :assistant, response)

      # Record usage
      record_usage(organisation_id)

      # Broadcast completion
      broadcast(conversation_id, {:message_complete, response})

      :ok
    else
      {:error, reason} ->
        Logger.error("Agent run failed: #{inspect(reason)}")
        broadcast(conversation_id, {:error, reason})
        {:error, reason}
    end
  end

  defp get_provider(:anthropic), do: FounderPad.AI.Providers.Anthropic
  defp get_provider(:openai), do: FounderPad.AI.Providers.OpenAI
  defp get_provider(_), do: FounderPad.AI.Providers.Anthropic

  defp agent_opts(agent) do
    [
      model: agent.model,
      system_prompt: agent.system_prompt,
      max_tokens: agent.max_tokens,
      temperature: agent.temperature
    ]
  end

  defp build_messages(conversation_id, new_content) do
    # Fetch existing messages for context
    existing =
      AI.Message
      |> Ash.Query.filter(conversation_id: conversation_id)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.read!()
      |> Enum.map(fn msg -> %{role: msg.role, content: msg.content} end)

    existing ++ [%{role: :user, content: new_content}]
  end

  defp create_message(conversation_id, role, content) do
    AI.Message
    |> Ash.Changeset.for_create(:create, %{
      role: role,
      content: content,
      conversation_id: conversation_id
    })
    |> Ash.create()
  end

  defp record_usage(organisation_id) do
    FounderPad.Billing.UsageRecord
    |> Ash.Changeset.for_create(:create, %{
      event_type: "agent.run",
      quantity: 1,
      organisation_id: organisation_id
    })
    |> Ash.create()
  end

  defp broadcast(conversation_id, message) do
    Phoenix.PubSub.broadcast(
      FounderPad.PubSub,
      "conversation:#{conversation_id}",
      message
    )
  end
end
