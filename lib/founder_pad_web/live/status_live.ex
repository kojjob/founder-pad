defmodule FounderPadWeb.StatusLive do
  use FounderPadWeb, :live_view

  alias FounderPad.System.Incident

  require Ash.Query

  @components [
    %{name: "API", icon: "api"},
    %{name: "Dashboard", icon: "dashboard"},
    %{name: "AI Agents", icon: "smart_toy"},
    %{name: "Billing", icon: "payments"},
    %{name: "Email", icon: "email"}
  ]

  def mount(_params, _session, socket) do
    active_incidents = load_active_incidents()
    recent_incidents = load_recent_incidents()

    affected =
      active_incidents
      |> Enum.flat_map(& &1.affected_components)
      |> MapSet.new()

    {:ok,
     assign(socket,
       page_title: "System Status",
       components: @components,
       active_incidents: active_incidents,
       recent_incidents: recent_incidents,
       affected_components: affected,
       all_operational: Enum.empty?(active_incidents)
     ), layout: false}
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>System Status - FounderPad</title>
        <link rel="stylesheet" href="/assets/css/app.css" />
        <link
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0"
          rel="stylesheet"
        />
        <script defer src="/assets/js/app.js">
        </script>
      </head>
      <body class="bg-background text-on-surface font-body min-h-screen">
        <div class="max-w-3xl mx-auto px-4 py-12 space-y-10">
          <%!-- Header --%>
          <div class="text-center space-y-3">
            <div class="flex items-center justify-center gap-3">
              <div class="w-10 h-10 rounded-lg bg-primary flex items-center justify-center">
                <span class="material-symbols-outlined text-on-primary text-2xl">architecture</span>
              </div>
              <h1 class="text-4xl font-extrabold font-headline tracking-tight">
                System Status
              </h1>
            </div>

            <%= if @all_operational do %>
              <div class="inline-flex items-center gap-2 px-4 py-2 bg-green-500/10 text-green-400 rounded-full font-medium">
                <span class="w-2.5 h-2.5 bg-green-400 rounded-full animate-pulse"></span>
                All Systems Operational
              </div>
            <% else %>
              <div class="inline-flex items-center gap-2 px-4 py-2 bg-amber-500/10 text-amber-400 rounded-full font-medium">
                <span class="w-2.5 h-2.5 bg-amber-400 rounded-full animate-pulse"></span>
                Some systems are experiencing issues
              </div>
            <% end %>
          </div>

          <%!-- Components Status --%>
          <div class="bg-surface-container rounded-xl overflow-hidden">
            <div class="px-6 py-4 border-b border-outline-variant/20">
              <h2 class="text-lg font-bold text-on-surface">Components</h2>
            </div>
            <div class="divide-y divide-outline-variant/10">
              <div :for={component <- @components} class="flex items-center justify-between px-6 py-4">
                <div class="flex items-center gap-3">
                  <span class="material-symbols-outlined text-on-surface-variant">
                    {component.icon}
                  </span>
                  <span class="font-medium text-on-surface">{component.name}</span>
                </div>
                <%= if MapSet.member?(@affected_components, component.name) do %>
                  <span class="inline-flex items-center gap-1.5 text-amber-400 text-sm font-medium">
                    <span class="w-2 h-2 bg-amber-400 rounded-full"></span> Degraded
                  </span>
                <% else %>
                  <span class="inline-flex items-center gap-1.5 text-green-400 text-sm font-medium">
                    <span class="w-2 h-2 bg-green-400 rounded-full"></span> Operational
                  </span>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Uptime Bar (last 30 days) --%>
          <div class="bg-surface-container rounded-xl p-6 space-y-3">
            <h2 class="text-lg font-bold text-on-surface">Uptime - Last 30 Days</h2>
            <div class="flex gap-0.5">
              <div
                :for={_day <- 1..30}
                class="flex-1 h-8 bg-green-500/80 rounded-sm first:rounded-l-md last:rounded-r-md"
              >
              </div>
            </div>
            <div class="flex justify-between text-xs text-on-surface-variant">
              <span>30 days ago</span>
              <span>Today</span>
            </div>
          </div>

          <%!-- Active Incidents --%>
          <%= unless Enum.empty?(@active_incidents) do %>
            <div class="bg-surface-container rounded-xl overflow-hidden">
              <div class="px-6 py-4 border-b border-outline-variant/20">
                <h2 class="text-lg font-bold text-on-surface">Active Incidents</h2>
              </div>
              <div class="divide-y divide-outline-variant/10">
                <div :for={incident <- @active_incidents} class="px-6 py-4 space-y-2">
                  <div class="flex items-center justify-between">
                    <h3 class="font-semibold text-on-surface">{incident.title}</h3>
                    <span class={[
                      "text-xs font-semibold px-2 py-0.5 rounded-full uppercase tracking-wider",
                      severity_class(incident.severity)
                    ]}>
                      {incident.severity}
                    </span>
                  </div>
                  <p :if={incident.description} class="text-sm text-on-surface-variant">
                    {incident.description}
                  </p>
                  <div class="flex items-center gap-4 text-xs text-on-surface-variant">
                    <span class="capitalize">{incident.status}</span>
                    <span>{format_time(incident.inserted_at)}</span>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Recent Incident History --%>
          <div class="bg-surface-container rounded-xl overflow-hidden">
            <div class="px-6 py-4 border-b border-outline-variant/20">
              <h2 class="text-lg font-bold text-on-surface">Incident History</h2>
            </div>
            <%= if Enum.empty?(@recent_incidents) do %>
              <div class="px-6 py-8 text-center text-on-surface-variant">
                No recent incidents
              </div>
            <% else %>
              <div class="divide-y divide-outline-variant/10">
                <div :for={incident <- @recent_incidents} class="px-6 py-4 space-y-1">
                  <div class="flex items-center justify-between">
                    <h3 class="font-medium text-on-surface">{incident.title}</h3>
                    <div class="flex items-center gap-2">
                      <span class={[
                        "text-xs font-semibold px-2 py-0.5 rounded-full uppercase tracking-wider",
                        severity_class(incident.severity)
                      ]}>
                        {incident.severity}
                      </span>
                      <span class={[
                        "text-xs font-medium px-2 py-0.5 rounded-full",
                        status_class(incident.status)
                      ]}>
                        {incident.status}
                      </span>
                    </div>
                  </div>
                  <p class="text-xs text-on-surface-variant">
                    {format_time(incident.inserted_at)}
                  </p>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Footer --%>
          <div class="text-center text-sm text-on-surface-variant">
            <a href="/" class="text-primary hover:text-primary/80 transition-colors">
              FounderPad
            </a>
          </div>
        </div>
      </body>
    </html>
    """
  end

  defp severity_class(:critical), do: "bg-red-500/20 text-red-400"
  defp severity_class(:major), do: "bg-amber-500/20 text-amber-400"
  defp severity_class(:minor), do: "bg-blue-500/20 text-blue-400"
  defp severity_class(_), do: "bg-surface-container-highest text-on-surface-variant"

  defp status_class(:resolved), do: "bg-green-500/10 text-green-400"
  defp status_class(:investigating), do: "bg-amber-500/10 text-amber-400"
  defp status_class(:identified), do: "bg-orange-500/10 text-orange-400"
  defp status_class(:monitoring), do: "bg-blue-500/10 text-blue-400"
  defp status_class(_), do: "bg-surface-container-highest text-on-surface-variant"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %H:%M UTC")
  end

  defp load_active_incidents do
    case Incident
         |> Ash.Query.for_read(:active)
         |> Ash.read(authorize?: false) do
      {:ok, incidents} -> incidents
      _ -> []
    end
  end

  defp load_recent_incidents do
    case Incident
         |> Ash.Query.for_read(:recent)
         |> Ash.read(authorize?: false) do
      {:ok, incidents} -> incidents
      _ -> []
    end
  end
end
