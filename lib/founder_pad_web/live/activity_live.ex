defmodule FounderPadWeb.ActivityLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_nav: :activity,
       page_title: "Activity Feed",
       events: sample_events()
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <section class="flex items-end justify-between">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">Activity Feed</h1>
          <p class="text-on-surface-variant mt-1">Real-time event stream across your workspace</p>
        </div>
        <div class="flex gap-2">
          <button class="px-3 py-1.5 text-sm font-medium bg-surface-container-high rounded-md text-on-surface hover:bg-surface-container-highest transition-colors">
            All
          </button>
          <button class="px-3 py-1.5 text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors">
            Agents
          </button>
          <button class="px-3 py-1.5 text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors">
            Billing
          </button>
          <button class="px-3 py-1.5 text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors">
            Team
          </button>
        </div>
      </section>

      <div class="space-y-3">
        <div
          :for={event <- @events}
          class="bg-surface-container rounded-lg p-5 flex items-start gap-4 hover:bg-surface-container-high/50 transition-colors"
        >
          <div class={"w-10 h-10 rounded-lg flex items-center justify-center shrink-0 bg-#{event.color}/10"}>
            <span class={"material-symbols-outlined text-#{event.color}"}>{event.icon}</span>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1">
              <span class="font-semibold text-sm">{event.actor}</span>
              <span class="text-on-surface-variant text-sm">{event.action}</span>
            </div>
            <p :if={event.detail} class="text-sm text-on-surface-variant">{event.detail}</p>
            <span class="text-xs font-mono text-on-surface-variant/60 mt-1 block">
              {event.time}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp sample_events do
    [
      %{
        actor: "Research Assistant",
        action: "completed a query",
        detail: "Processed 2,400 tokens in 1.2s",
        time: "2 min ago",
        icon: "check_circle",
        color: "primary"
      },
      %{
        actor: "Sarah Chen",
        action: "invited a team member",
        detail: "alex@company.com added as member",
        time: "15 min ago",
        icon: "person_add",
        color: "secondary"
      },
      %{
        actor: "Code Reviewer",
        action: "run failed",
        detail: "Rate limit exceeded on OpenAI provider",
        time: "1 hour ago",
        icon: "error",
        color: "error"
      },
      %{
        actor: "System",
        action: "plan upgraded",
        detail: "Starter → Pro plan active",
        time: "3 hours ago",
        icon: "upgrade",
        color: "secondary"
      },
      %{
        actor: "Data Analyzer",
        action: "completed batch processing",
        detail: "142 records processed, 3 anomalies detected",
        time: "5 hours ago",
        icon: "analytics",
        color: "primary"
      }
    ]
  end
end
