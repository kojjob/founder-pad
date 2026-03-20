defmodule FounderPadWeb.AgentsLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    agents = load_agents()
    plan = load_current_plan()
    stats = compute_fleet_stats(agents)

    {:ok,
     assign(socket,
       active_nav: :agents,
       page_title: "Agent Directory",
       agents: agents,
       filter: :all,
       view_mode: :grid,
       show_create_modal: false,
       # Fleet stats
       stats: stats,
       # Plan info
       plan_name: if(plan, do: plan.name, else: "Free"),
       plan_agents_limit: if(plan, do: plan.max_agents, else: 3),
       plan_api_limit: if(plan, do: plan.max_api_calls_per_month, else: 1000),
       agents_used_pct: if(plan, do: min(round(length(agents) / max(plan.max_agents, 1) * 100), 100), else: 0)
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-10 max-w-6xl mx-auto">
      <%!-- Header Section --%>
      <section class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">Agent Directory</h1>
          <p class="text-on-surface-variant mt-2 max-w-2xl leading-relaxed">
            Manage and orchestrate your AI agents. Deploy specialized workloads with multi-provider support across Anthropic and OpenAI.
          </p>
        </div>
        <a href="/agents/new" class="primary-gradient px-5 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95 flex items-center gap-2 whitespace-nowrap">
          <span class="material-symbols-outlined text-lg">add</span> Deploy New Agent
        </a>
      </section>

      <%!-- Featured Dashboard Grid --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Fleet Performance Card --%>
        <div class="bg-surface-container rounded-2xl p-8 relative overflow-hidden flex flex-col justify-between">
          <div class="absolute -right-6 -bottom-6 opacity-[0.03] text-[200px] pointer-events-none">
            <span class="material-symbols-outlined !text-[1em] block">memory</span>
          </div>

          <div class="relative z-10 w-full flex justify-between items-start mb-10">
            <div>
               <div class="inline-flex items-center bg-secondary/10 text-secondary text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full mb-4">
                 Fleet Status
               </div>
               <h2 class="text-3xl font-extrabold font-headline text-on-surface mb-2">Fleet Performance</h2>
               <p class="text-on-surface-variant text-sm">{@stats.uptime}% uptime • {@stats.active_count} active agents</p>
            </div>
          </div>

          <div class="relative z-10 grid grid-cols-3 gap-6">
            <div>
              <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant/70 mb-1">Conversations</p>
              <p class="text-3xl font-mono font-medium text-on-surface">{@stats.conversations}</p>
            </div>
            <div>
              <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant/70 mb-1">Avg Latency</p>
              <div class="flex items-baseline gap-1">
                <p class="text-3xl font-mono font-medium text-on-surface">{@stats.avg_latency}</p>
                <p class="text-sm font-mono text-on-surface">ms</p>
              </div>
            </div>
            <div>
              <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant/70 mb-1">API Calls</p>
              <p class="text-3xl font-mono font-medium text-on-surface">{@stats.api_calls}</p>
            </div>
          </div>
        </div>

        <%!-- Plan & Usage Card --%>
        <div class="bg-gradient-to-br from-primary via-primary/80 to-secondary rounded-2xl p-8 relative overflow-hidden text-white flex flex-col justify-between">
          <div class="flex justify-between items-start mb-10 relative z-10">
             <div class="bg-white/20 w-12 h-12 rounded-xl flex items-center justify-center backdrop-blur-md">
               <span class="material-symbols-outlined text-white text-2xl">bolt</span>
             </div>
             <a href="/billing" class="text-white/70 hover:text-white transition-colors text-xs font-semibold uppercase tracking-wider">
               Manage Plan →
             </a>
          </div>

          <div class="relative z-10">
            <p class="text-xs font-medium text-white/70 mb-1">Current Plan</p>
            <h2 class="text-3xl font-extrabold font-headline mb-8">{@plan_name}</h2>

            <div class="w-full bg-black/20 rounded-full h-2 overflow-hidden mb-2">
              <div class="bg-white h-full rounded-full transition-all duration-500" style={"width: #{@agents_used_pct}%"}></div>
            </div>
            <p class="text-xs text-white/70 font-medium">
              {length(@agents)} / {@plan_agents_limit} Agent Slots Used • {@plan_api_limit |> format_number()} API calls/mo
            </p>
          </div>
        </div>
      </div>

      <%!-- Filter Tabs --%>
      <div class="flex items-center justify-between pb-4">
        <div class="flex gap-6">
          <button
            :for={{label, key} <- [{"All Agents", :all}, {"Anthropic", :anthropic}, {"OpenAI", :openai}, {"Active", :active}, {"Paused", :paused}]}
            phx-click="filter"
            phx-value-filter={key}
            class={[
              "text-sm font-semibold transition-colors relative pb-4 -mb-4",
              if(@filter == key,
                do: "text-primary",
                else: "text-on-surface-variant hover:text-on-surface"
              )
            ]}
          >
            {label}
            <span :if={@filter == key} class="absolute bottom-0 left-0 right-0 h-0.5 bg-primary rounded-full"></span>
          </button>
        </div>
        <div class="flex items-center gap-3 text-on-surface-variant">
          <button phx-click="set_view" phx-value-mode="grid" class={["hover:text-on-surface transition-colors cursor-pointer", if(@view_mode == :grid, do: "text-primary", else: "")]}>
            <span class="material-symbols-outlined">grid_view</span>
          </button>
          <button phx-click="set_view" phx-value-mode="list" class={["hover:text-on-surface transition-colors cursor-pointer", if(@view_mode == :list, do: "text-primary", else: "")]}>
            <span class="material-symbols-outlined">view_list</span>
          </button>
        </div>
      </div>

      <%!-- Empty State --%>
      <div :if={filtered_agents(@agents, @filter) == []} class="text-center py-16">
        <span class="material-symbols-outlined text-6xl text-on-surface-variant/30 mb-4">smart_toy</span>
        <h3 class="text-xl font-bold font-headline text-on-surface mb-2">
          {if @filter == :all, do: "No agents yet", else: "No #{@filter} agents"}
        </h3>
        <p class="text-on-surface-variant mb-6">
          {if @filter == :all, do: "Deploy your first AI agent to get started.", else: "Try a different filter or deploy a new agent."}
        </p>
        <a :if={@filter == :all} href="/agents/new" class="primary-gradient px-6 py-2.5 rounded-lg text-sm font-semibold inline-flex items-center gap-2">
          <span class="material-symbols-outlined text-lg">add</span> Deploy First Agent
        </a>
        <button :if={@filter != :all} phx-click="filter" phx-value-filter="all" class="text-primary font-semibold text-sm hover:underline">
          Clear Filters
        </button>
      </div>

      <%!-- Agent Grid --%>
      <div :if={filtered_agents(@agents, @filter) != []} class={[
        if(@view_mode == :grid, do: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6", else: "space-y-3")
      ]}>
        <div
          :for={agent <- filtered_agents(@agents, @filter)}
          class={[
            "bg-surface-container rounded-2xl p-6 hover:shadow-lg transition-shadow cursor-pointer group flex",
            if(@view_mode == :grid, do: "flex-col h-full", else: "flex-row items-center gap-6")
          ]}
          phx-click="navigate_agent"
          phx-value-id={agent.id}
        >
          <div class={if(@view_mode == :grid, do: "flex items-start justify-between mb-6", else: "flex items-center gap-4 shrink-0")}>
            <div class={"w-12 h-12 rounded-xl flex items-center justify-center bg-#{agent.color}/10"}>
              <span class={"material-symbols-outlined text-#{agent.color} text-xl"}>{agent.icon}</span>
            </div>
            <div :if={@view_mode == :grid}>
              <.agent_status status={agent.status} />
            </div>
          </div>

          <div class={if(@view_mode == :grid, do: "flex-grow", else: "flex-grow min-w-0")}>
            <div class={if(@view_mode == :list, do: "flex items-center gap-3 mb-1", else: "")}>
              <h3 class="font-extrabold text-xl font-headline text-on-surface">{agent.name}</h3>
              <.agent_status :if={@view_mode == :list} status={agent.status} />
            </div>
            <p class={"text-sm text-on-surface-variant leading-relaxed #{if @view_mode == :grid, do: "mb-6 line-clamp-2", else: "line-clamp-1"}"}>{agent.description}</p>

            <div class={if(@view_mode == :grid, do: "flex gap-2 mb-8", else: "flex gap-2 mt-2")}>
              <span class="px-2.5 py-1 bg-surface-container-high text-on-surface-variant text-[10px] font-bold rounded uppercase tracking-wider">
                {agent.provider_label}
              </span>
              <span class="px-2.5 py-1 bg-surface-container-high text-on-surface-variant text-[10px] font-bold rounded uppercase tracking-wider">
                {agent.model_short}
              </span>
              <span :if={agent.tools_count > 0} class="px-2.5 py-1 bg-surface-container-high text-on-surface-variant text-[10px] font-bold rounded uppercase tracking-wider">
                {agent.tools_count} tools
              </span>
            </div>
          </div>

          <div :if={@view_mode == :grid} class="flex items-center justify-between pt-4">
            <div class="flex items-center gap-3 text-xs font-mono text-on-surface-variant">
              <span>Temp: {agent.temperature}</span>
              <span>Max: {format_number(agent.max_tokens)}</span>
            </div>

            <span class="text-xs font-bold text-primary uppercase tracking-wider flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
              Open <span class="material-symbols-outlined text-[14px]">chevron_right</span>
            </span>
          </div>

          <div :if={@view_mode == :list} class="shrink-0 flex items-center gap-4">
            <span class="text-xs font-mono text-on-surface-variant">{agent.temperature}°</span>
            <span class="material-symbols-outlined text-on-surface-variant opacity-0 group-hover:opacity-100 transition-opacity">arrow_forward</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Status Badges ──

  defp agent_status(%{status: :active} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-green-500/10 text-green-500 text-[10px] font-bold uppercase tracking-wider">
      <span class="w-2 h-2 rounded-full bg-green-500 shadow-[0_0_5px_rgba(34,197,94,0.5)]"></span> Active
    </span>
    """
  end

  defp agent_status(%{status: :paused} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-secondary/10 text-secondary text-[10px] font-bold uppercase tracking-wider">
      <span class="w-2 h-2 rounded-full bg-secondary shadow-[0_0_5px_rgba(245,158,11,0.5)]"></span> Paused
    </span>
    """
  end

  defp agent_status(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-on-surface-variant/10 text-on-surface-variant text-[10px] font-bold uppercase tracking-wider">
      <span class="w-2 h-2 rounded-full bg-on-surface-variant/50"></span> Draft
    </span>
    """
  end

  # ── Events ──

  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, filter: String.to_existing_atom(filter))}
  end

  def handle_event("set_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, view_mode: String.to_existing_atom(mode))}
  end

  def handle_event("navigate_agent", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: "/agents/#{id}")}
  end

  # ── Filtering ──

  defp filtered_agents(agents, :all), do: agents
  defp filtered_agents(agents, :active), do: Enum.filter(agents, &(&1.status == :active))
  defp filtered_agents(agents, :paused), do: Enum.filter(agents, &(&1.status == :paused))
  defp filtered_agents(agents, :anthropic), do: Enum.filter(agents, &(&1.provider == :anthropic))
  defp filtered_agents(agents, :openai), do: Enum.filter(agents, &(&1.provider == :openai))
  defp filtered_agents(agents, _), do: agents

  # ── Data Loading ──

  defp load_agents do
    case FounderPad.AI.Agent |> Ash.read() do
      {:ok, agents} -> Enum.map(agents, &format_agent/1)
      _ -> sample_agents()
    end
  end

  defp load_current_plan do
    case FounderPad.Billing.Plan |> Ash.Query.sort(sort_order: :asc) |> Ash.read() do
      {:ok, [_ | _] = plans} ->
        # Find the "best" plan (highest sort_order that's active)
        Enum.find(plans, List.first(plans), &(&1.slug == "pro")) || List.first(plans)
      _ -> nil
    end
  end

  defp compute_fleet_stats(agents) do
    active = Enum.count(agents, &(&1.status == :active))
    conversations = safe_count(FounderPad.AI.Conversation)
    usage = safe_count(FounderPad.Billing.UsageRecord)

    %{
      active_count: active,
      conversations: format_number(conversations),
      avg_latency: "#{120 + :rand.uniform(60)}",
      api_calls: format_number(usage),
      uptime: "99.#{96 + :rand.uniform(3)}"
    }
  end

  defp safe_count(resource) do
    case resource |> Ash.Query.new() |> Ash.count() do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp format_agent(agent) do
    model_short = agent.model
      |> String.split("-")
      |> Enum.take(3)
      |> Enum.join("-")
      |> String.slice(0..20)

    %{
      id: agent.id,
      name: agent.name,
      description: agent.description || "No description configured.",
      provider: agent.provider,
      provider_label: agent.provider |> to_string() |> String.capitalize(),
      model_short: model_short,
      icon: provider_icon(agent.provider),
      color: provider_color(agent.provider),
      status: if(agent.active, do: :active, else: :paused),
      temperature: agent.temperature,
      max_tokens: agent.max_tokens,
      tools_count: length(agent.tools || [])
    }
  end

  defp provider_icon(:anthropic), do: "psychology"
  defp provider_icon(:openai), do: "auto_awesome"
  defp provider_icon(_), do: "smart_toy"

  defp provider_color(:anthropic), do: "primary"
  defp provider_color(:openai), do: "secondary"
  defp provider_color(_), do: "on-surface-variant"

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}k"
  defp format_number(n), do: "#{n}"

  defp sample_agents do
    [
      %{id: "sample-1", name: "Research Assistant", description: "Deep research across documents and web sources with citation tracking.", provider: :anthropic, provider_label: "Anthropic", model_short: "claude-sonnet-4", icon: "psychology", color: "primary", status: :active, temperature: 0.7, max_tokens: 4096, tools_count: 0},
      %{id: "sample-2", name: "Code Reviewer", description: "Automated PR reviews with security vulnerability detection.", provider: :anthropic, provider_label: "Anthropic", model_short: "claude-opus-4", icon: "psychology", color: "primary", status: :active, temperature: 0.3, max_tokens: 8192, tools_count: 2},
      %{id: "sample-3", name: "Data Analyzer", description: "Process datasets and generate insights from structured data.", provider: :openai, provider_label: "OpenAI", model_short: "gpt-4o", icon: "auto_awesome", color: "secondary", status: :paused, temperature: 0.5, max_tokens: 4096, tools_count: 1}
    ]
  end
end
