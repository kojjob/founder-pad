defmodule FounderPadWeb.AgentDetailLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(%{"id" => agent_id}, _session, socket) do
    case Ash.get(FounderPad.AI.Agent, agent_id) do
      {:ok, agent} ->
        user = socket.assigns[:current_user]
        conversation = get_or_create_conversation(agent, user)
        messages = load_messages(conversation.id)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(FounderPad.PubSub, "conversation:#{conversation.id}")
        end

        {:ok,
         assign(socket,
           active_nav: :agents,
           page_title: agent.name,
           agent: agent,
           conversation: conversation,
           messages: messages,
           message_input: "",
           streaming: false
         )}

      {:error, _} ->
        {:ok, push_navigate(socket, to: "/agents")}
    end
  end

  def handle_event("send_message", %{"message" => content}, socket)
      when content != "" do
    conversation = socket.assigns.conversation
    agent = socket.assigns.agent

    %{
      conversation_id: conversation.id,
      message_content: content,
      organisation_id: agent.organisation_id
    }
    |> FounderPad.AI.Workers.AgentRunner.new()
    |> Oban.insert()

    user_msg = %{role: :user, content: content, time: "Just now"}

    {:noreply,
     socket
     |> assign(messages: socket.assigns.messages ++ [user_msg])
     |> assign(message_input: "")
     |> assign(streaming: true)}
  end

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_info({:message_complete, response}, socket) do
    assistant_msg = %{role: :assistant, content: response, time: "Just now"}

    {:noreply,
     socket
     |> assign(messages: socket.assigns.messages ++ [assistant_msg])
     |> assign(streaming: false)}
  end

  def handle_info({:error, reason}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Agent error: #{inspect(reason)}")
     |> assign(streaming: false)}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Agent Header --%>
      <section class="flex items-start justify-between">
        <div class="flex items-center gap-4">
          <div class="w-14 h-14 rounded-xl bg-primary/10 flex items-center justify-center">
            <span class="material-symbols-outlined text-primary text-3xl">science</span>
          </div>
          <div>
            <div class="flex items-center gap-3">
              <h1 class="text-3xl font-extrabold font-headline">{@agent.name}</h1>
              <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-green-500/10 text-green-400 text-xs font-bold">
                Active
              </span>
            </div>
            <p class="text-on-surface-variant mt-1">{@agent.description}</p>
            <div class="flex gap-4 mt-2 text-xs font-mono text-on-surface-variant">
              <span>{@agent.provider} • {@agent.model}</span>
              <span>Temp: {@agent.temperature}</span>
              <span>Max: {@agent.max_tokens} tokens</span>
            </div>
          </div>
        </div>
        <div class="flex gap-2">
          <button class="px-4 py-2 bg-surface-container-high rounded-lg text-sm font-medium hover:bg-surface-container-highest transition-colors">
            Edit
          </button>
          <button class="px-4 py-2 primary-gradient rounded-lg text-sm font-semibold">
            Run Agent
          </button>
        </div>
      </section>

      <%!-- Stats Row --%>
      <section class="grid grid-cols-4 gap-4">
        <div class="bg-surface-container p-4 rounded-lg text-center">
          <p class="text-xs font-mono text-on-surface-variant mb-1">CONVERSATIONS</p>
          <p class="text-2xl font-mono font-medium text-primary">128</p>
        </div>
        <div class="bg-surface-container p-4 rounded-lg text-center">
          <p class="text-xs font-mono text-on-surface-variant mb-1">TOKENS_USED</p>
          <p class="text-2xl font-mono font-medium text-on-surface">2.4M</p>
        </div>
        <div class="bg-surface-container p-4 rounded-lg text-center">
          <p class="text-xs font-mono text-on-surface-variant mb-1">AVG_LATENCY</p>
          <p class="text-2xl font-mono font-medium text-on-surface">142ms</p>
        </div>
        <div class="bg-surface-container p-4 rounded-lg text-center">
          <p class="text-xs font-mono text-on-surface-variant mb-1">SUCCESS_RATE</p>
          <p class="text-2xl font-mono font-medium text-primary">99.2%</p>
        </div>
      </section>

      <%!-- Conversation Area --%>
      <section class="bg-surface-container-low rounded-lg border border-outline-variant/10 overflow-hidden">
        <div class="px-6 py-4 border-b border-outline-variant/10 flex items-center justify-between">
          <h3 class="font-bold font-headline">Recent Conversation</h3>
          <span class="text-xs font-mono text-on-surface-variant">
            ID: {String.slice(@conversation.id, 0..11)}...
          </span>
        </div>
        <div class="p-6 space-y-6 max-h-[500px] overflow-y-auto" id="messages-container" phx-hook="ScrollBottom">
          <div :for={msg <- @messages} class="flex gap-4">
            <div class={[
              "w-8 h-8 rounded-lg flex items-center justify-center shrink-0",
              if(msg.role == :user, do: "bg-surface-container-highest", else: "bg-primary/10")
            ]}>
              <span class={[
                "material-symbols-outlined text-sm",
                if(msg.role == :user, do: "text-on-surface", else: "text-primary")
              ]}>
                {if msg.role == :user, do: "person", else: "smart_toy"}
              </span>
            </div>
            <div class="flex-1">
              <p class="text-xs font-mono text-on-surface-variant mb-1">
                {if msg.role == :user, do: "You", else: @agent.name} • {msg.time}
              </p>
              <div class="text-sm leading-relaxed">{msg.content}</div>
            </div>
          </div>
          <div :if={@streaming} class="flex gap-4">
            <div class="w-8 h-8 rounded-lg flex items-center justify-center shrink-0 bg-primary/10">
              <span class="material-symbols-outlined text-sm text-primary">smart_toy</span>
            </div>
            <div class="flex-1">
              <p class="text-xs font-mono text-on-surface-variant mb-1">{@agent.name} • thinking...</p>
              <div class="flex gap-1">
                <span class="w-2 h-2 bg-primary/50 rounded-full animate-bounce"></span>
                <span class="w-2 h-2 bg-primary/50 rounded-full animate-bounce [animation-delay:0.15s]"></span>
                <span class="w-2 h-2 bg-primary/50 rounded-full animate-bounce [animation-delay:0.3s]"></span>
              </div>
            </div>
          </div>
        </div>
        <%!-- Input --%>
        <div class="px-6 py-4 border-t border-outline-variant/10">
          <form phx-submit="send_message" class="flex gap-3">
            <input
              type="text"
              name="message"
              value={@message_input}
              placeholder={if @streaming, do: "Agent is thinking...", else: "Send a message..."}
              disabled={@streaming}
              class="flex-1 bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant/50 focus:ring-1 focus:ring-primary disabled:opacity-50"
              autofocus
            />
            <button
              type="submit"
              disabled={@streaming}
              class="primary-gradient px-4 py-2.5 rounded-lg text-sm font-semibold transition-transform active:scale-95 disabled:opacity-50"
            >
              <span class="material-symbols-outlined text-lg">
                {if @streaming, do: "hourglass_top", else: "send"}
              </span>
            </button>
          </form>
        </div>
      </section>
    </div>
    """
  end

  # -- Private helpers --------------------------------------------------------

  defp get_or_create_conversation(agent, user) do
    case FounderPad.AI.Conversation
         |> Ash.Query.filter(agent_id: agent.id, status: :active)
         |> Ash.Query.limit(1)
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.read() do
      {:ok, [conversation | _]} ->
        conversation

      _ ->
        {:ok, conversation} =
          FounderPad.AI.Conversation
          |> Ash.Changeset.for_create(:create, %{
            title: "Chat with #{agent.name}",
            agent_id: agent.id,
            organisation_id: agent.organisation_id,
            user_id: user && user.id
          })
          |> Ash.create()

        conversation
    end
  end

  defp load_messages(conversation_id) do
    case FounderPad.AI.Message
         |> Ash.Query.filter(conversation_id: conversation_id)
         |> Ash.Query.sort(inserted_at: :asc)
         |> Ash.read() do
      {:ok, messages} ->
        Enum.map(messages, fn msg ->
          %{role: msg.role, content: msg.content, time: format_time(msg.inserted_at)}
        end)

      _ ->
        []
    end
  end

  defp format_time(nil), do: "---"
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M")
end
