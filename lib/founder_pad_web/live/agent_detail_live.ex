defmodule FounderPadWeb.AgentDetailLive do
  use FounderPadWeb, :live_view

  def mount(%{"id" => _id}, _session, socket) do
    agent = sample_agent()

    {:ok,
     assign(socket,
       active_nav: :agents,
       page_title: agent.name,
       agent: agent,
       messages: sample_messages()
     )}
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
          <button class="px-4 py-2 bg-gradient-to-br from-primary to-primary-container text-on-primary-fixed rounded-lg text-sm font-semibold">
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
          <span class="text-xs font-mono text-on-surface-variant">ID: conv_82fa3...1d</span>
        </div>
        <div class="p-6 space-y-6 max-h-[500px] overflow-y-auto">
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
        </div>
        <%!-- Input --%>
        <div class="px-6 py-4 border-t border-outline-variant/10">
          <div class="flex gap-3">
            <input
              type="text"
              placeholder="Send a message..."
              class="flex-1 bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant/50 focus:ring-1 focus:ring-primary"
            />
            <button class="bg-gradient-to-br from-primary to-primary-container text-on-primary-fixed px-4 py-2.5 rounded-lg text-sm font-semibold transition-transform active:scale-95">
              <span class="material-symbols-outlined text-lg">send</span>
            </button>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp sample_agent do
    %{
      name: "Research Assistant",
      description:
        "Deep research across documents, papers, and web sources with citation tracking.",
      provider: "Anthropic",
      model: "Claude Sonnet 4",
      temperature: 0.7,
      max_tokens: 4096
    }
  end

  defp sample_messages do
    [
      %{
        role: :user,
        content:
          "Can you analyze the competitive landscape for AI SaaS boilerplates in the Phoenix/Elixir ecosystem?",
        time: "2 min ago"
      },
      %{
        role: :assistant,
        content:
          "I'll research the current landscape. Based on my analysis, the Phoenix/Elixir ecosystem has a few notable SaaS boilerplates, but none with comprehensive AI agent integration. The main competitors are: 1) Petal Pro — focused on UI components, 2) LiveSaaS — basic auth/billing, 3) SaaSKit — Rails-based competitor. FounderPad's differentiator is the built-in AI agent orchestration with multi-provider support.",
        time: "1 min ago"
      },
      %{
        role: :user,
        content: "What about pricing models? How do they compare?",
        time: "30s ago"
      }
    ]
  end
end
