defmodule FounderPadWeb.AgentsLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_nav: :agents,
       page_title: "AI Agents",
       agents: sample_agents(),
       filter: :all
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <section class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">Agent Directory</h1>
          <p class="text-on-surface-variant mt-1">Manage and monitor your AI agents</p>
        </div>
        <button class="primary-gradient font-semibold px-4 py-2 rounded-lg text-sm transition-transform active:scale-95">
          <span class="flex items-center gap-2">
            <span class="material-symbols-outlined text-lg">add</span>
            New Agent
          </span>
        </button>
      </section>

      <%!-- Filter Tabs --%>
      <div class="flex gap-2">
        <button
          :for={
            {label, key} <- [{"All", :all}, {"Active", :active}, {"Paused", :paused}, {"Draft", :draft}]
          }
          phx-click="filter"
          phx-value-filter={key}
          class={[
            "px-3 py-1.5 text-sm font-medium rounded-md transition-colors",
            if(@filter == key,
              do: "bg-surface-container-high text-on-surface",
              else: "text-on-surface-variant hover:text-on-surface"
            )
          ]}
        >
          {label}
        </button>
      </div>

      <%!-- Agent Grid --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div
          :for={agent <- filtered_agents(@agents, @filter)}
          class="bg-surface-container rounded-lg p-6 hover:bg-surface-container-high/50 transition-all cursor-pointer group border border-transparent hover:border-outline-variant/20"
        >
          <div class="flex items-start justify-between mb-4">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
                <span class="material-symbols-outlined text-primary">{agent.icon}</span>
              </div>
              <div>
                <h3 class="font-semibold">{agent.name}</h3>
                <p class="text-xs font-mono text-on-surface-variant">
                  {agent.provider} • {agent.model}
                </p>
              </div>
            </div>
            <.agent_status status={agent.status} />
          </div>
          <p class="text-sm text-on-surface-variant mb-4 line-clamp-2">{agent.description}</p>
          <div class="flex items-center justify-between text-xs">
            <div class="flex gap-4 font-mono text-on-surface-variant">
              <span>{agent.conversations} convos</span>
              <span>{agent.tokens_used} tokens</span>
            </div>
            <span class="text-on-surface-variant/60 font-mono">{agent.last_used}</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp agent_status(%{status: :active} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-green-500/10 text-green-400 text-[10px] font-bold">
      <span class="w-1.5 h-1.5 rounded-full bg-green-400"></span> Active
    </span>
    """
  end

  defp agent_status(%{status: :paused} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-on-surface-variant/10 text-on-surface-variant text-[10px] font-bold">
      <span class="w-1.5 h-1.5 rounded-full bg-on-surface-variant/50"></span> Paused
    </span>
    """
  end

  defp agent_status(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-outline-variant/10 text-outline text-[10px] font-bold">
      Draft
    </span>
    """
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, filter: String.to_existing_atom(filter))}
  end

  defp filtered_agents(agents, :all), do: agents

  defp filtered_agents(agents, status) do
    Enum.filter(agents, fn agent -> agent.status == status end)
  end

  defp sample_agents do
    [
      %{
        name: "Research Assistant",
        description:
          "Deep research across documents, papers, and web sources with citation tracking.",
        provider: "Anthropic",
        model: "Claude Sonnet",
        icon: "science",
        status: :active,
        conversations: 128,
        tokens_used: "2.4M",
        last_used: "2m ago"
      },
      %{
        name: "Code Reviewer",
        description:
          "Automated PR reviews with security vulnerability detection and performance suggestions.",
        provider: "Anthropic",
        model: "Claude Opus",
        icon: "code",
        status: :active,
        conversations: 56,
        tokens_used: "890K",
        last_used: "15m ago"
      },
      %{
        name: "Data Analyzer",
        description:
          "Process datasets, generate insights, and create visualizations from structured data.",
        provider: "OpenAI",
        model: "GPT-4o",
        icon: "analytics",
        status: :paused,
        conversations: 34,
        tokens_used: "1.1M",
        last_used: "1h ago"
      },
      %{
        name: "Content Writer",
        description:
          "Generate blog posts, documentation, and marketing copy with brand voice consistency.",
        provider: "Anthropic",
        model: "Claude Sonnet",
        icon: "edit_note",
        status: :active,
        conversations: 89,
        tokens_used: "3.2M",
        last_used: "5m ago"
      },
      %{
        name: "Customer Support",
        description:
          "Handle customer queries with context from knowledge base and past interactions.",
        provider: "OpenAI",
        model: "GPT-4o-mini",
        icon: "support_agent",
        status: :draft,
        conversations: 0,
        tokens_used: "0",
        last_used: "Never"
      },
      %{
        name: "SQL Assistant",
        description:
          "Generate, optimize, and explain SQL queries across PostgreSQL and MySQL.",
        provider: "Anthropic",
        model: "Claude Haiku",
        icon: "database",
        status: :active,
        conversations: 203,
        tokens_used: "450K",
        last_used: "30s ago"
      }
    ]
  end
end
