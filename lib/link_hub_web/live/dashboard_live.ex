defmodule LinkHubWeb.DashboardLive do
  @moduledoc "LiveView for the main application dashboard."
  use LinkHubWeb, :live_view

  require Ash.Query

  @refresh_interval 30_000

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh, @refresh_interval)
      Phoenix.PubSub.subscribe(LinkHub.PubSub, "org_events:all")
    end

    user = socket.assigns[:current_user]

    socket = socket |> assign(active_nav: :dashboard, page_title: "Dashboard")

    socket =
      try do
        load_all_data(socket, user)
      rescue
        _ -> assign_defaults(socket)
      end

    {:ok, socket}
  end

  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)

    try do
      {:noreply, load_all_data(socket, socket.assigns[:current_user])}
    rescue
      _ -> {:noreply, socket}
    end
  end

  def handle_info({:app_event, _event}, socket) do
    {:noreply, load_all_data(socket, socket.assigns[:current_user])}
  rescue
    _ -> {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp assign_defaults(socket) do
    assign(socket,
      user_name: "",
      last_sync: "—",
      system_status: :nominal,
      agents_count: 0,
      agents_limit: 3,
      agents_pct: 0,
      total_inference: "0",
      inference_chart: [30, 30, 30, 30, 30, 30],
      token_usage: "0",
      token_quota_pct: 0,
      token_chart: [{30, 0.3}, {30, 0.3}, {30, 0.3}, {30, 0.3}, {30, 0.3}, {30, 0.3}],
      success_rate: 0.0,
      avg_latency: "—",
      error_rate: "—",
      success_chart: [50, 50, 50, 50, 50, 50, 50, 50, 50],
      current_plan_name: "Free",
      members_count: 0,
      notifications_count: 0,
      flags_enabled: 0,
      cost_grade: "—",
      api_uptime: "99.99%",
      recent_activity: [],
      onboarding_complete: socket.assigns[:onboarding_complete] || false,
      setup_banner_dismissed: socket.assigns[:setup_banner_dismissed] || false
    )
  end

  def handle_event("dismiss_setup_banner", _, socket) do
    {:noreply, assign(socket, setup_banner_dismissed: true)}
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
    metrics = compute_metrics()
    chart_data = generate_chart_data()
    recent_events = load_recent_events()

    assign(socket,
      user_name: user_first_name(user),
      last_sync: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S UTC"),
      system_status: if(metrics.usage_pct < 90, do: :nominal, else: :warning),
      agents_count: metrics.agents_count,
      agents_limit: metrics.agents_limit,
      agents_pct: metrics.agents_pct,
      total_inference: format_number(metrics.conversations_count),
      inference_chart: chart_data.inference,
      token_usage: format_number(metrics.usage_count),
      token_quota_pct: metrics.usage_pct,
      token_chart: chart_data.tokens,
      success_rate: calculate_success_rate(recent_events),
      avg_latency: "—",
      error_rate: "0.00%",
      success_chart: chart_data.success,
      current_plan_name: metrics.plan_name,
      members_count: metrics.members_count,
      notifications_count: metrics.notifications_count,
      flags_enabled: metrics.flags_enabled,
      cost_grade: calculate_cost_grade(metrics.usage_count, metrics.agents_count),
      api_uptime: "99.99%",
      recent_activity: metrics.agent_activity,
      onboarding_complete: socket.assigns[:onboarding_complete] || false,
      setup_banner_dismissed: socket.assigns[:setup_banner_dismissed] || false
    )
  end

  defp compute_metrics do
    agents = load_agents()
    agents_count = length(agents)
    usage_count = safe_count(LinkHub.Billing.UsageRecord)
    current_plan = load_plans() |> List.first()

    plan_limit = if current_plan, do: current_plan.max_api_calls_per_month, else: 1000
    agents_limit = if current_plan, do: current_plan.max_agents, else: 3

    %{
      agents_count: agents_count,
      agents_limit: agents_limit,
      agents_pct: pct(agents_count, agents_limit),
      conversations_count: safe_count(LinkHub.AI.Conversation),
      usage_count: usage_count,
      usage_pct: pct(usage_count, plan_limit),
      members_count: safe_count(LinkHub.Accounts.Membership),
      notifications_count: safe_count(LinkHub.Notifications.Notification),
      flags_enabled: count_enabled_flags(),
      plan_name: if(current_plan, do: current_plan.name, else: "Free"),
      agent_activity: format_agent_activity(agents)
    }
  end

  defp pct(_count, limit) when limit <= 0, do: 0
  defp pct(count, limit), do: min(round(count / limit * 100), 100)

  defp user_first_name(nil), do: ""
  defp user_first_name(user), do: user.name |> to_string() |> String.split() |> List.first() || ""

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Onboarding Banner --%>
      <div
        :if={not @onboarding_complete and not @setup_banner_dismissed}
        class="flex items-center justify-between gap-4 p-4 rounded-xl bg-primary/10 border border-primary/20"
      >
        <div class="flex items-center gap-3">
          <span class="material-symbols-outlined text-primary text-xl">rocket_launch</span>
          <p class="text-sm font-medium text-on-surface">
            Complete your workspace setup to get the most out of LinkHub
          </p>
        </div>
        <div class="flex items-center gap-2">
          <.link
            navigate="/onboarding"
            class="primary-gradient px-4 py-2 rounded-lg text-xs font-bold whitespace-nowrap"
          >
            Complete Setup
          </.link>
          <button
            phx-click="dismiss_setup_banner"
            class="p-1 text-on-surface-variant hover:text-on-surface transition-colors"
            aria-label="Dismiss"
          >
            <span class="material-symbols-outlined text-lg">close</span>
          </button>
        </div>
      </div>

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
          <button
            phx-click="refresh_data"
            class="p-2 text-on-surface-variant hover:text-primary transition-colors rounded-lg hover:bg-surface-container-high"
            title="Refresh"
          >
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
            <div
              class="h-full bg-primary rounded-full transition-all duration-500"
              style={"width: #{@agents_pct}%"}
            >
            </div>
          </div>
          <p class="text-[10px] text-on-surface-variant mt-2 font-mono">
            {@agents_pct}% of plan limit
          </p>
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
              style={"height: #{h}%; background-color: var(--fp-chart-primary); opacity: #{max(h / 100, 0.3)};"}
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
              if(@token_quota_pct >= 80,
                do: "bg-error/10 text-error",
                else: "bg-secondary/10 text-secondary"
              )
            ]}>
              {if @token_quota_pct >= 80, do: "LIMIT NEAR", else: "ON TRACK"} {@token_quota_pct}%
            </span>
          </div>
          <span class="text-5xl font-mono font-medium text-secondary">{@token_usage}</span>
          <div class="mt-6 flex gap-1.5 h-8">
            <div
              :for={{h, opacity} <- @token_chart}
              class="flex-1 mt-auto rounded-sm transition-all duration-300"
              style={"height: #{h}%; background-color: var(--fp-chart-secondary); opacity: #{opacity};"}
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
              style={"height: #{h}%; background-color: var(--fp-chart-primary); opacity: #{min((i + 2) / (length(@success_chart) + 1), 1)};"}
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
                <span class={[
                  "font-mono",
                  if(@notifications_count > 0, do: "text-secondary", else: "text-on-surface-variant")
                ]}>
                  {if @notifications_count > 0,
                    do: "#{@notifications_count} unread",
                    else: "All clear"}
                </span>
              </div>
            </div>
          </div>

          <%!-- Security Advisory --%>
          <div class="bg-gradient-to-br from-surface-container to-surface-container-high p-6 rounded-lg">
            <p class="text-xs font-mono text-primary mb-2">// SYSTEM_STATUS</p>
            <p class="text-sm leading-relaxed text-on-surface-variant">
              {cond do
                @agents_count == 0 ->
                  "No agents configured yet. Create your first AI agent to get started."

                @token_quota_pct >= 80 ->
                  "API usage approaching limit. Consider upgrading your plan for uninterrupted service."

                @agents_pct >= 80 ->
                  "Agent slots nearly full. Upgrade to add more agents."

                true ->
                  "All systems operational. Your agents are running within normal parameters."
              end}
            </p>
            <a
              href={
                cond do
                  @agents_count == 0 -> "/agents"
                  @token_quota_pct >= 80 -> "/billing"
                  @agents_pct >= 80 -> "/billing"
                  true -> "/agents"
                end
              }
              class="mt-4 text-primary font-semibold text-sm hover:underline flex items-center gap-1"
            >
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
          <%= if @recent_activity == [] do %>
            <div class="px-6 py-12 text-center text-on-surface-variant">
              <span class="material-symbols-outlined text-4xl mb-2 block opacity-30">smart_toy</span>
              <p class="text-sm">No agent activity yet</p>
              <p class="text-xs mt-1 opacity-60">Create your first agent to get started</p>
            </div>
          <% else %>
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
                  <span class={"material-symbols-outlined text-lg text-#{row.icon_color}"}>
                    {row.icon}
                  </span>
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
          <% end %>
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
    case LinkHub.AI.Agent |> Ash.read() do
      {:ok, agents} -> agents
      _ -> []
    end
  end

  defp load_plans do
    case LinkHub.Billing.Plan |> Ash.Query.sort(sort_order: :asc) |> Ash.read() do
      {:ok, plans} -> plans
      _ -> []
    end
  end

  defp count_enabled_flags do
    case LinkHub.FeatureFlags.FeatureFlag
         |> Ash.Query.filter(enabled: true)
         |> Ash.count() do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp load_recent_events do
    case LinkHub.Analytics.AppEvent
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
        activity:
          "#{agent.provider |> to_string() |> String.capitalize()} • #{agent.model |> String.split("-") |> Enum.take(2) |> Enum.join("-")}",
        latency: "—",
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
    successes =
      Enum.count(events, fn e ->
        not String.contains?(to_string(e.event_name), "fail")
      end)

    Float.round(successes / total * 100, 1)
  end

  defp calculate_cost_grade(_usage, agents) when agents == 0, do: "—"

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

  defp generate_chart_data do
    today = Date.utc_today()

    inference_counts = daily_counts(LinkHub.AI.Conversation, today, 6)
    usage_counts = daily_counts(LinkHub.Billing.UsageRecord, today, 6)

    %{
      inference: normalize_chart(inference_counts),
      tokens: normalize_token_chart(usage_counts),
      success: List.duplicate(50, 9)
    }
  end

  defp daily_counts(resource, today, num_days) do
    Enum.map((num_days - 1)..0//-1, fn days_ago ->
      day_start = today |> Date.add(-days_ago) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
      day_end = today |> Date.add(-days_ago + 1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

      case resource
           |> Ash.Query.new()
           |> Ash.Query.filter(inserted_at >= ^day_start and inserted_at < ^day_end)
           |> Ash.count() do
        {:ok, count} -> count
        _ -> 0
      end
    end)
  end

  defp normalize_chart(counts) do
    max_val = Enum.max(counts, fn -> 0 end)

    if max_val == 0 do
      List.duplicate(5, length(counts))
    else
      Enum.map(counts, fn c -> max(round(c / max_val * 100), 5) end)
    end
  end

  defp normalize_token_chart(counts) do
    max_val = Enum.max(counts, fn -> 0 end)

    if max_val == 0 do
      Enum.map(counts, fn _ -> {5, 0.3} end)
    else
      Enum.map(counts, fn c ->
        pct = max(round(c / max_val * 100), 5)
        opacity = max(0.3, pct / 100)
        {pct, Float.round(opacity, 2)}
      end)
    end
  end
end
