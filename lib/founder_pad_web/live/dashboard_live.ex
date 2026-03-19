defmodule FounderPadWeb.DashboardLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_nav: :dashboard,
       page_title: "Dashboard",
       agents_count: 42,
       total_inference: "892.4k",
       token_usage: "4.2M",
       token_quota_pct: 82,
       success_rate: 98.7,
       avg_latency: "182ms",
       error_rate: "0.02%",
       recent_activity: sample_activity()
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Editorial Header --%>
      <section class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div class="space-y-1">
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">Command Center</h1>
          <p class="text-on-surface-variant font-medium">
            System Health: <span class="text-primary">Nominal</span> •
            Latency: <span class="font-mono text-xs">{@avg_latency}</span>
          </p>
        </div>
        <div class="flex items-center gap-2 text-sm font-mono text-on-surface-variant bg-surface-container-low px-3 py-1.5 rounded-sm border border-outline-variant/10">
          <span class="w-2 h-2 rounded-full bg-secondary animate-pulse"></span>
          LAST_SYNC: {Calendar.strftime(DateTime.utc_now(), "%H:%M:%S UTC")}
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
            <span class="text-xs font-mono text-secondary">+12% vs LY</span>
          </div>
          <div class="mt-6 h-1 w-full bg-surface-container-highest rounded-full overflow-hidden">
            <div class="h-full bg-primary w-3/4"></div>
          </div>
        </div>

        <%!-- Total Inference Card --%>
        <div class="md:col-span-4 bg-surface-container p-6 rounded-lg">
          <p class="text-sm font-medium text-on-surface-variant mb-4">Total Inference</p>
          <div class="flex items-baseline gap-2">
            <span class="text-5xl font-mono font-medium text-on-surface">{@total_inference}</span>
          </div>
          <div class="mt-4 flex gap-1 items-end h-12">
            <div
              :for={h <- [40, 60, 55, 80, 70, 100]}
              class="flex-1 bg-primary/20 rounded-t-sm"
              style={"height: #{h}%"}
            >
            </div>
          </div>
        </div>

        <%!-- Token Usage Card --%>
        <div class="md:col-span-4 bg-surface-container p-6 rounded-lg">
          <div class="flex justify-between items-start mb-4">
            <p class="text-sm font-medium text-on-surface-variant">Token Usage</p>
            <span class="text-[10px] font-mono bg-secondary/10 text-secondary px-2 py-0.5 rounded-full">
              QUOTA REACHED {@token_quota_pct}%
            </span>
          </div>
          <span class="text-5xl font-mono font-medium text-secondary">{@token_usage}</span>
          <div class="mt-6 flex gap-1.5 h-8">
            <div class="flex-1 bg-secondary h-4 mt-auto rounded-sm opacity-40"></div>
            <div class="flex-1 bg-secondary h-6 mt-auto rounded-sm opacity-60"></div>
            <div class="flex-1 bg-secondary h-5 mt-auto rounded-sm opacity-50"></div>
            <div class="flex-1 bg-secondary h-8 mt-auto rounded-sm"></div>
            <div class="flex-1 bg-surface-container-highest h-8 mt-auto rounded-sm"></div>
            <div class="flex-1 bg-surface-container-highest h-8 mt-auto rounded-sm"></div>
          </div>
        </div>

        <%!-- Success Rate Large Card --%>
        <div class="md:col-span-8 bg-surface-container-low border border-outline-variant/10 rounded-lg p-8 flex flex-col justify-between">
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
            </div>
          </div>
          <div class="mt-12 relative h-48 flex items-end justify-between gap-1">
            <div
              :for={{h, i} <- Enum.with_index([60, 65, 72, 85, 82, 92, 88, 98, 85])}
              class="w-full rounded-t-lg"
              style={"height: #{h}%; background-color: rgba(192, 193, 255, #{(i + 1) / 10});"}
            >
            </div>
          </div>
        </div>

        <%!-- Quick Insights Sidebar --%>
        <div class="md:col-span-4 space-y-6">
          <div class="bg-surface-container-highest/30 p-6 rounded-lg border border-outline-variant/10">
            <h4 class="text-sm font-bold uppercase tracking-wider text-on-surface-variant mb-4">
              Quick Insights
            </h4>
            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <span class="text-sm">Cost Efficiency</span>
                <span class="font-mono text-secondary">A+</span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm">Compute Load</span>
                <span class="font-mono text-on-surface">34.2%</span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm">API Uptime</span>
                <span class="font-mono text-primary">99.99%</span>
              </div>
            </div>
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
          <div class="grid grid-cols-12 gap-4 px-6 py-4 border-b border-outline-variant/5 bg-surface-container/30 text-xs font-mono uppercase tracking-widest text-on-surface-variant">
            <div class="col-span-4">Agent</div>
            <div class="col-span-3">Activity</div>
            <div class="col-span-2">Latency</div>
            <div class="col-span-2">Status</div>
            <div class="col-span-1"></div>
          </div>
          <div
            :for={row <- @recent_activity}
            class="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-surface-container-high/50 transition-colors group"
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
              <button class="material-symbols-outlined text-on-surface-variant opacity-0 group-hover:opacity-100 transition-opacity">
                more_vert
              </button>
            </div>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp status_badge(%{status: :running} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-primary/10 text-primary text-[10px] font-bold border border-primary/20">
      <span class="w-1.5 h-1.5 rounded-full bg-primary"></span> Running
    </span>
    """
  end

  defp status_badge(%{status: :completed} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-green-500/10 text-green-400 text-[10px] font-bold border border-green-500/20">
      <span class="w-1.5 h-1.5 rounded-full bg-green-400"></span> Completed
    </span>
    """
  end

  defp status_badge(%{status: :failed} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-error/10 text-error text-[10px] font-bold border border-error/20">
      <span class="w-1.5 h-1.5 rounded-full bg-error"></span> Failed
    </span>
    """
  end

  defp status_badge(%{status: :paused} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-on-surface-variant/10 text-on-surface-variant text-[10px] font-bold border border-outline-variant/20">
      <span class="w-1.5 h-1.5 rounded-full bg-on-surface-variant/50"></span> Paused
    </span>
    """
  end

  defp sample_activity do
    [
      %{
        name: "Research Assistant",
        short_id: "0x82f...a1",
        activity: "Natural Language Query",
        latency: "142ms",
        status: :running,
        icon: "bolt",
        icon_color: "primary"
      },
      %{
        name: "Data Analyzer",
        short_id: "0x93a...c4",
        activity: "Dataset Processing",
        latency: "--",
        status: :paused,
        icon: "dataset",
        icon_color: "secondary"
      },
      %{
        name: "Code Reviewer",
        short_id: "0x11b...09",
        activity: "PR Analysis",
        latency: "ERR",
        status: :failed,
        icon: "code",
        icon_color: "error"
      }
    ]
  end
end
