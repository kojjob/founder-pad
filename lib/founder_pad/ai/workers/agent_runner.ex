defmodule FounderPad.AI.Workers.AgentRunner do
  @moduledoc """
  Oban worker that runs AI agent conversations.
  Broadcasts streaming results via PubSub.
  """
  use Oban.Worker, queue: :ai, max_attempts: 3

  require Logger
  require Ash.Query

  alias FounderPad.AI
  alias FounderPad.Notifications

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "conversation_id" => conversation_id,
          "message_content" => _message_content,
          "organisation_id" => organisation_id
        }
      }) do
    # Note: user message is already saved by the LiveView before enqueuing this job
    with {:ok, conversation} <- Ash.get(AI.Conversation, conversation_id, load: [:agent]),
         provider <- get_provider(conversation.agent.provider),
         messages <- build_messages(conversation_id, nil),
         {:ok, response} <- provider.chat(messages, agent_opts(conversation.agent)) do
      # Save assistant message
      {:ok, _assistant_msg} = create_message(conversation_id, :assistant, response)

      # Record usage
      record_usage(organisation_id)

      # Broadcast completion
      broadcast(conversation_id, {:message_complete, response})

      # Notify user of completion
      notify_agent_completed(conversation, conversation.agent)

      :ok
    else
      {:error, reason} ->
        Logger.error("Agent run failed: #{inspect(reason)}")
        broadcast(conversation_id, {:error, reason})

        # Notify user of failure
        case Ash.get(AI.Conversation, conversation_id, load: [:agent]) do
          {:ok, conv} -> notify_agent_failed(conv, inspect(reason))
          _ -> :ok
        end

        {:error, reason}
    end
  end

  @doc "Creates an agent_completed notification and broadcasts it to the user."
  def notify_agent_completed(conversation, agent) do
    user_id = conversation.user_id

    if user_id do
      {:ok, notif} =
        Notifications.Notification
        |> Ash.Changeset.for_create(:create, %{
          type: :agent_completed,
          title: "#{agent.name} completed a run",
          body: "Agent run completed successfully",
          action_url: "/agents/#{agent.id}",
          user_id: user_id
        })
        |> Ash.create()

      Notifications.broadcast_to_user(user_id, notif)
    end

    :ok
  end

  @doc "Creates an agent_failed notification and broadcasts it to the user."
  def notify_agent_failed(conversation, reason) do
    user_id = conversation.user_id

    if user_id do
      {:ok, notif} =
        Notifications.Notification
        |> Ash.Changeset.for_create(:create, %{
          type: :agent_failed,
          title: "Agent run failed",
          body: "Agent run failed: #{reason}",
          user_id: user_id
        })
        |> Ash.create()

      Notifications.broadcast_to_user(user_id, notif)
    end

    :ok
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

  defp build_messages(conversation_id, _new_content) do
    # Fetch all messages (user message already saved by LiveView)
    AI.Message
    |> Ash.Query.filter(conversation_id: conversation_id)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!()
    |> Enum.map(fn msg -> %{role: msg.role, content: msg.content} end)
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
