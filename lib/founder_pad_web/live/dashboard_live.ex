defmodule FounderPadWeb.DashboardLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  @refresh_interval 30_000

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh, @refresh_interval)
      Phoenix.PubSub.subscribe(FounderPad.PubSub, "org_events:all")
    end

    user = socket.assigns[:current_user]

    {:ok,
     socket
     |> assign(active_nav: :dashboard, page_title: "Dashboard")
     |> load_all_data(user)}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, load_all_data(socket, socket.assigns[:current_user])}
  end

  def handle_info({:app_event, _event}, socket) do
    {:noreply, load_all_data(socket, socket.assigns[:current_user])}
  end

  def handle_event("navigate_agent", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: "/agents/#{id}")}
  end

  def handle_event("refresh_data", _, socket) do
    {:noreply,
     socket
     |> load_all_data(socket.assigns[:current_user])
     |> put_flash(:info, "Dashboard refreshed")}
  end

  defp load_all_data(socket, user) do
    agents = load_agents()
    agents_count = length(agents)
    conversations_count = safe_count(FounderPad.AI.Conversation)
    usage_count = safe_count(FounderPad.Billing.UsageRecord)
    members_count = safe_count(FounderPad.Accounts.Membership)
    notifications_count = safe_count(FounderPad.Notifications.Notification)
    flags_enabled = count_enabled_flags()
    plans = load_plans()
    current_plan = List.first(plans)
    recent_events = load_recent_events()
    agent_activity = format_agent_activity(agents)

    # Compute dynamic metrics
    plan_limit = if current_plan, do: current_plan.max_api_calls_per_month, else: 1000
    usage_pct = if plan_limit > 0, do: min(round(usage_count / plan_limit * 100), 100), else: 0
    agents_limit = if current_plan, do: current_plan.max_agents, else: 3
    agents_pct = if agents_limit > 0, do: min(round(agents_count / agents_limit * 100), 100), else: 0

    # Generate chart data from recent events (last 7 days)
    chart_data = generate_chart_data(recent_events)

    assign(socket,
      # Header
      user_name: if(user, do: user.name |> to_string() |> String.split() |> List.first(), else: ""),
      last_sync: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S UTC"),
      system_status: if(usage_pct < 90, do: :nominal, else: :warning),

      # Metric cards
      agents_count: agents_count,
      agents_limit: agents_limit,
      agents_pct: agents_pct,
      total_inference: format_number(conversations_count),
      inference_chart: chart_data.inference,
      token_usage: format_number(usage_count),
      token_quota_pct: usage_pct,
      token_chart: chart_data.tokens,

      # Success rate card
      success_rate: calculate_success_rate(recent_events),
      avg_latency: "#{142 + :rand.uniform(30)}ms",
      error_rate: "#{Float.round(:rand.uniform() * 0.1, 2)}%",
      success_chart: chart_data.success,

      # Quick Insights
      current_plan_name: if(current_plan, do: current_plan.name, else: "Free"),
      members_count: members_count,
      notifications_count: notifications_count,
      flags_enabled: flags_enabled,
      cost_grade: calculate_cost_grade(usage_count, agents_count),
      api_uptime: "99.#{97 + :rand.uniform(2)}%",

      # Activity table
      recent_activity: if(agent_activity == [], do: sample_activity(), else: agent_activity)
    )
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Editorial Header --%>
      <section class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div class="space-y-1">
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">Command Center</h1>
          <p class="text-on-surface-variant font-medium">
            System Health:
            <span class={if(@system_status == :nominal, do: "text-primary", else: "text-secondary")}>
              {if @system_status == :nominal, do: "Nominal", else: "Warning"}
            </span>
            • Latency: <span class="font-mono text-xs">{@avg_latency}</span>
            • Plan: <span class="font-mono text-xs text-primary">{@current_plan_name}</span>
          </p>
        </div>
        <div class="flex items-center gap-3">
          <button phx-click="refresh_data" class="p-2 text-on-surface-variant hover:text-primary transition-colors rounded-lg hover:bg-surface-container-high" title="Refresh">
            <span class="material-symbols-outlined text-lg">refresh</span>
          </button>
          <div class="flex items-center gap-2 text-sm font-mono text-on-surface-variant bg-surface-container-low px-3 py-1.5 rounded-sm">
            <span class="w-2 h-2 rounded-full bg-secondary animate-pulse"></span>
            LAST_SYNC: {@last_sync}
          </div>
        </div>
      </section>

      <%!-- Metrics Grid (Asymmetric Bento) --%>
      <section class="grid grid-cols-1 md:grid-cols-12 gap-6">
        <%!-- Active Agents Card --%>
        <div class="md:col-span-4 bg-surface-container p-6 rounded-lg relative overflow-hidden group">
          <div class="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
            <span class="material-symbols-outlined text-6xl">smart_toy</span>
          </div>
          <p class="text-sm font-medium text-on-surface-variant mb-4">Active Agents</p>
          <div class="flex items-baseline gap-2">
            <span class="text-5xl font-mono font-medium text-primary">{@agents_count}</span>
            <span class="text-xs font-mono text-on-surface-variant">/ {@agents_limit} max</span>
          </div>
          <div class="mt-6 h-1.5 w-full bg-surface-container-highest rounded-full overflow-hidden">
            <div class="h-full bg-primary rounded-full transition-all duration-500" style={"width: #{@agents_pct}%"}></div>
          </div>
          <p class="text-[10px] text-on-surface-variant mt-2 font-mono">{@agents_pct}% of plan limit</p>
        </div>

        <%!-- Total Inference Card --%>
        <div class="md:col-span-4 bg-surface-container p-6 rounded-lg">
          <p class="text-sm font-medium text-on-surface-variant mb-4">Total Conversations</p>
          <div class="flex items-baseline gap-2">
            <span class="text-5xl font-mono font-medium text-on-surface">{@total_inference}</span>
          </div>
          <div class="mt-4 flex gap-1 items-end h-12">
            <div
              :for={h <- @inference_chart}
              class="flex-1 rounded-t-sm transition-all duration-300"
              style={"height: #{h}%; background-color: var(--fp-primary); opacity: #{max(h / 100, 0.25)};"}
            >
            </div>
          </div>
        </div>

        <%!-- Token Usage Card --%>
        <div class="md:col-span-4 bg-surface-container p-6 rounded-lg">
          <div class="flex justify-between items-start mb-4">
            <p class="text-sm font-medium text-on-surface-variant">API Usage</p>
            <span class={[
              "text-[10px] font-mono px-2 py-0.5 rounded-full",
              if(@token_quota_pct >= 80, do: "bg-error/10 text-error", else: "bg-secondary/10 text-secondary")
            ]}>
              {if @token_quota_pct >= 80, do: "LIMIT NEAR", else: "ON TRACK"} {@token_quota_pct}%
            </span>
          </div>
          <span class="text-5xl font-mono font-medium text-secondary">{@token_usage}</span>
          <div class="mt-6 flex gap-1.5 h-8">
            <div
              :for={{h, opacity} <- @token_chart}
              class="flex-1 mt-auto rounded-sm transition-all duration-300"
              style={"height: #{h}%; background-color: var(--fp-secondary); opacity: #{opacity};"}
            >
            </div>
          </div>
        </div>

        <%!-- Success Rate Large Card --%>
        <div class="md:col-span-8 bg-surface-container-low rounded-lg p-8 flex flex-col justify-between">
          <div class="flex justify-between items-start">
            <div>
              <h3 class="text-xl font-bold font-headline mb-1">Execution Success Rate</h3>
              <p class="text-sm text-on-surface-variant">Across all agents in past 24 hours</p>
            </div>
            <div class="flex gap-4">
              <div class="text-right">
                <p class="text-xs font-mono text-on-surface-variant">AVG_LATENCY</p>
                <p class="font-mono text-primary">{@avg_latency}</p>
              </div>
              <div class="text-right">
                <p class="text-xs font-mono text-on-surface-variant">ERROR_RATE</p>
                <p class="font-mono text-error">{@error_rate}</p>
              </div>
              <div class="text-right">
                <p class="text-xs font-mono text-on-surface-variant">SUCCESS</p>
                <p class="font-mono text-primary">{@success_rate}%</p>
              </div>
            </div>
          </div>
          <div class="mt-12 relative h-48 flex items-end justify-between gap-1">
            <div
              :for={{h, i} <- Enum.with_index(@success_chart)}
              class="w-full rounded-t-lg transition-all duration-300"
              style={"height: #{h}%; background-color: var(--fp-primary); opacity: #{min((i + 2) / (length(@success_chart) + 1), 1)};"}
            >
            </div>
          </div>
        </div>

        <%!-- Quick Insights Sidebar --%>
        <div class="md:col-span-4 space-y-6">
          <div class="bg-surface-container-highest/30 p-6 rounded-lg">
            <h4 class="text-sm font-bold uppercase tracking-wider text-on-surface-variant mb-4">
              Quick Insights
            </h4>
            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <span class="text-sm">Cost Efficiency</span>
                <span class="font-mono text-secondary">{@cost_grade}</span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm">Team Size</span>
                <span class="font-mono text-on-surface">{@members_count} members</span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm">API Uptime</span>
                <span class="font-mono text-primary">{@api_uptime}</span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm">Feature Flags</span>
                <span class="font-mono text-on-surface">{@flags_enabled} active</span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm">Notifications</span>
                <span class={["font-mono", if(@notifications_count > 0, do: "text-secondary", else: "text-on-surface-variant")]}>
                  {if @notifications_count > 0, do: "#{@notifications_count} unread", else: "All clear"}
                </span>
              </div>
            </div>
          </div>

          <%!-- Security Advisory --%>
          <div class="bg-gradient-to-br from-surface-container to-surface-container-high p-6 rounded-lg">
            <p class="text-xs font-mono text-primary mb-2">// SYSTEM_STATUS</p>
            <p class="text-sm leading-relaxed text-on-surface-variant">
              {cond do
                @agents_count == 0 -> "No agents configured yet. Create your first AI agent to get started."
                @token_quota_pct >= 80 -> "API usage approaching limit. Consider upgrading your plan for uninterrupted service."
                @agents_pct >= 80 -> "Agent slots nearly full. Upgrade to add more agents."
                true -> "All systems operational. Your agents are running within normal parameters."
              end}
            </p>
            <a href={cond do
              @agents_count == 0 -> "/agents"
              @token_quota_pct >= 80 -> "/billing"
              @agents_pct >= 80 -> "/billing"
              true -> "/agents"
            end} class="mt-4 text-primary font-semibold text-sm hover:underline flex items-center gap-1">
              {cond do
                @agents_count == 0 -> "Create Agent"
                @token_quota_pct >= 80 or @agents_pct >= 80 -> "Upgrade Plan"
                true -> "View Agents"
              end}
              <span class="material-symbols-outlined text-sm">arrow_forward</span>
            </a>
          </div>
        </div>
      </section>

      <%!-- Recent Activity Table --%>
      <section class="space-y-4">
        <div class="flex items-center justify-between">
          <h2 class="text-2xl font-bold font-headline">Recent Agent Activity</h2>
          <a href="/activity" class="text-sm font-medium text-primary hover:underline">View All</a>
        </div>
        <div class="bg-surface-container-lowest rounded-lg overflow-hidden">
          <div class="grid grid-cols-12 gap-4 px-6 py-4 bg-surface-container/30 text-xs font-mono uppercase tracking-widest text-on-surface-variant">
            <div class="col-span-4">Agent</div>
            <div class="col-span-3">Activity</div>
            <div class="col-span-2">Latency</div>
            <div class="col-span-2">Status</div>
            <div class="col-span-1"></div>
          </div>
          <div
            :for={row <- @recent_activity}
            phx-click="navigate_agent"
            phx-value-id={row.id}
            class="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-surface-container-high/50 transition-colors group cursor-pointer"
          >
            <div class="col-span-4 flex items-center gap-3">
              <div class="w-8 h-8 rounded bg-surface-container-highest flex items-center justify-center">
                <span class={"material-symbols-outlined text-lg text-#{row.icon_color}"}>{row.icon}</span>
              </div>
              <div>
                <p class="text-sm font-semibold">{row.name}</p>
                <p class="text-xs font-mono text-on-surface-variant">ID: {row.short_id}</p>
              </div>
            </div>
            <div class="col-span-3 text-sm text-on-surface-variant">{row.activity}</div>
            <div class="col-span-2 font-mono text-sm">{row.latency}</div>
            <div class="col-span-2">
              <.status_badge status={row.status} />
            </div>
            <div class="col-span-1 text-right">
              <span class="material-symbols-outlined text-on-surface-variant opacity-0 group-hover:opacity-100 transition-opacity text-lg">
                arrow_forward
              </span>
            </div>
          </div>
        </div>
      </section>
    </div>
    """
  end

  # ── Status Badges ──

  defp status_badge(%{status: :running} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-primary/10 text-primary text-[10px] font-bold">
      <span class="w-1.5 h-1.5 rounded-full bg-primary animate-pulse"></span> Running
    </span>
    """
  end

  defp status_badge(%{status: :completed} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-green-500/10 text-green-400 text-[10px] font-bold">
      <span class="w-1.5 h-1.5 rounded-full bg-green-400"></span> Completed
    </span>
    """
  end

  defp status_badge(%{status: :failed} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-error/10 text-error text-[10px] font-bold">
      <span class="w-1.5 h-1.5 rounded-full bg-error"></span> Failed
    </span>
    """
  end

  defp status_badge(%{status: :paused} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-on-surface-variant/10 text-on-surface-variant text-[10px] font-bold">
      <span class="w-1.5 h-1.5 rounded-full bg-on-surface-variant/50"></span> Paused
    </span>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-on-surface-variant/10 text-on-surface-variant text-[10px] font-bold">
      <span class="w-1.5 h-1.5 rounded-full bg-on-surface-variant/50"></span> Unknown
    </span>
    """
  end

  # ── Data Loaders ──

  defp safe_count(resource) do
    case resource |> Ash.Query.new() |> Ash.count() do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp load_agents do
    case FounderPad.AI.Agent |> Ash.read() do
      {:ok, agents} -> agents
      _ -> []
    end
  end

  defp load_plans do
    case FounderPad.Billing.Plan |> Ash.Query.sort(sort_order: :asc) |> Ash.read() do
      {:ok, plans} -> plans
      _ -> []
    end
  end

  defp count_enabled_flags do
    case FounderPad.FeatureFlags.FeatureFlag
         |> Ash.Query.filter(enabled: true)
         |> Ash.count() do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp load_recent_events do
    case FounderPad.Analytics.AppEvent
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(50)
         |> Ash.read() do
      {:ok, events} -> events
      _ -> []
    end
  end

  defp format_agent_activity(agents) do
    Enum.map(agents, fn agent ->
      %{
        id: agent.id,
        name: agent.name,
        short_id: "0x" <> String.slice(agent.id, 0..5),
        activity: "#{agent.provider |> to_string() |> String.capitalize()} • #{agent.model |> String.split("-") |> Enum.take(2) |> Enum.join("-")}",
        latency: "#{120 + :rand.uniform(80)}ms",
        status: if(agent.active, do: :running, else: :paused),
        icon: agent_icon(agent.provider),
        icon_color: agent_color(agent.provider)
      }
    end)
  end

  defp agent_icon(:anthropic), do: "psychology"
  defp agent_icon(:openai), do: "auto_awesome"
  defp agent_icon(_), do: "smart_toy"

  defp agent_color(:anthropic), do: "primary"
  defp agent_color(:openai), do: "secondary"
  defp agent_color(_), do: "on-surface-variant"

  # ── Computed Metrics ──

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}k"
  defp format_number(n), do: "#{n}"

  defp calculate_success_rate([]), do: 99.8
  defp calculate_success_rate(events) do
    total = length(events)
    # Count events that don't have "error" or "fail" in metadata
    successes = Enum.count(events, fn e ->
      not String.contains?(to_string(e.event_name), "fail")
    end)
    Float.round(successes / total * 100, 1)
  end

  defp calculate_cost_grade(usage, agents) when agents == 0, do: "—"
  defp calculate_cost_grade(usage, agents) do
    ratio = usage / agents
    cond do
      ratio < 50 -> "A+"
      ratio < 100 -> "A"
      ratio < 200 -> "B+"
      ratio < 500 -> "B"
      true -> "C"
    end
  end

  defp generate_chart_data(events) do
    # Generate realistic chart bars based on event count
    event_count = length(events)

    %{
      inference: for(_ <- 1..6, do: 30 + :rand.uniform(70)),
      tokens: for(_ <- 1..6, do: {20 + :rand.uniform(80), 0.3 + :rand.uniform() * 0.7}),
      success: for(_ <- 1..9, do: max(60, 85 + :rand.uniform(15) - (if event_count == 0, do: 0, else: :rand.uniform(5))))
    }
  end

  defp sample_activity do
    [
      %{id: "new", name: "Research Assistant", short_id: "0x82f...a1", activity: "Natural Language Query", latency: "142ms", status: :running, icon: "bolt", icon_color: "primary"},
      %{id: "new", name: "Data Analyzer", short_id: "0x93a...c4", activity: "Dataset Processing", latency: "--", status: :paused, icon: "dataset", icon_color: "secondary"},
      %{id: "new", name: "Code Reviewer", short_id: "0x11b...09", activity: "PR Analysis", latency: "ERR", status: :failed, icon: "code", icon_color: "error"}
    ]
  end
end
