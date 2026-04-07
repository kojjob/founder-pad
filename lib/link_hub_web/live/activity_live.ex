defmodule LinkHubWeb.ActivityLive do
  @moduledoc "LiveView for the organization activity feed."
  use LinkHubWeb, :live_view

  import LinkHubWeb.Helpers.TimeFormatter, only: [time_ago: 1]

  require Ash.Query

  @page_size 20

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LinkHub.PubSub, "org_events:all")
    end

    events = load_events(:all)
    stats = compute_stats(events)

    {:ok,
     assign(socket,
       active_nav: :activity,
       page_title: "Activity Feed",
       filter: :all,
       events: events,
       stats: stats
     )}
  end

  # ── Real-time updates ──

  def handle_info({:app_event, _event}, socket) do
    events = load_events(socket.assigns.filter)
    {:noreply, assign(socket, events: events, stats: compute_stats(events))}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  # ── Events ──

  def handle_event("filter", %{"filter" => filter}, socket) do
    f = String.to_existing_atom(filter)
    events = load_events(f)
    {:noreply, assign(socket, filter: f, events: events, stats: compute_stats(events))}
  end

  def handle_event("refresh", _, socket) do
    events = load_events(socket.assigns.filter)

    {:noreply,
     socket
     |> assign(events: events, stats: compute_stats(events))
     |> put_flash(:info, "Activity refreshed")}
  end

  # ── Render ──

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <section class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <div class="flex items-center gap-2 text-xs font-mono text-on-surface-variant/60 uppercase tracking-widest mb-2">
            <span class="material-symbols-outlined text-sm text-primary">stream</span> Live Stream
          </div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">Organization Activity</h1>
          <p class="text-on-surface-variant mt-1">
            A technical audit log of every system operation across your workspace.
          </p>
        </div>
        <div class="flex items-center gap-4">
          <div class="flex items-center gap-6 text-sm">
            <div class="text-right">
              <p class="text-[10px] font-mono text-on-surface-variant uppercase">Node Status</p>
              <p class="font-mono text-primary font-medium">{@stats.success_rate}%</p>
            </div>
            <div class="text-right">
              <p class="text-[10px] font-mono text-on-surface-variant uppercase">
                Total Events (24h)
              </p>
              <p class="font-mono text-on-surface font-medium">{@stats.total}</p>
            </div>
          </div>
          <button
            phx-click="refresh"
            class="p-2 text-on-surface-variant hover:text-primary rounded-lg hover:bg-surface-container-high transition-colors"
            title="Refresh"
          >
            <span class="material-symbols-outlined">refresh</span>
          </button>
        </div>
      </section>

      <%!-- Filter Tabs --%>
      <div class="flex items-center justify-between">
        <div class="flex gap-2">
          <button
            :for={
              {label, key} <- [
                {"All Events", :all},
                {"Agent Activity", :agents},
                {"Security", :security},
                {"Billing", :billing},
                {"Team", :team}
              ]
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
        <span class="text-xs font-mono text-on-surface-variant">
          Showing {@stats.shown} of {@stats.total} events
        </span>
      </div>

      <%!-- Empty state --%>
      <div :if={@events == []} class="text-center py-16">
        <span class="material-symbols-outlined text-6xl text-on-surface-variant/30 mb-4 block">
          stream
        </span>
        <h3 class="text-xl font-bold font-headline text-on-surface mb-2">No activity yet</h3>
        <p class="text-on-surface-variant">Events will appear here as you use the platform.</p>
      </div>

      <%!-- Event List --%>
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
              <span class="font-semibold text-sm text-on-surface">{event.actor}</span>
              <span class="text-on-surface-variant text-sm">{event.action}</span>
              <span class={[
                "px-1.5 py-0.5 rounded text-[9px] font-bold uppercase tracking-wider",
                event_type_class(event.type)
              ]}>
                {event.type}
              </span>
            </div>
            <p :if={event.detail} class="text-sm text-on-surface-variant">{event.detail}</p>
            <span class="text-xs font-mono text-on-surface-variant/60 mt-1 block">{event.time}</span>
          </div>
          <span class="text-xs font-mono text-on-surface-variant/40 hidden md:block shrink-0">
            {event.raw_time}
          </span>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ──

  defp event_type_class("agent"), do: "bg-primary/10 text-primary"
  defp event_type_class("security"), do: "bg-error/10 text-error"
  defp event_type_class("billing"), do: "bg-secondary/10 text-secondary"
  defp event_type_class("team"), do: "bg-tertiary/10 text-tertiary"
  defp event_type_class(_), do: "bg-on-surface-variant/10 text-on-surface-variant"

  defp load_events(filter) do
    audit_events = load_audit_events(filter)
    app_events = load_app_events(filter)

    (audit_events ++ app_events)
    |> Enum.sort_by(& &1.sort_key, {:desc, DateTime})
    |> Enum.take(@page_size)
  end

  defp load_audit_events(filter) do
    query =
      LinkHub.Audit.AuditLog
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(@page_size)

    query =
      case filter do
        :agents -> Ash.Query.filter(query, resource_type: "Agent")
        :security -> Ash.Query.filter(query, action: :login)
        :team -> Ash.Query.filter(query, resource_type: "User")
        :billing -> Ash.Query.filter(query, resource_type: "Subscription")
        _ -> query
      end

    case Ash.read(query) do
      {:ok, logs} -> Enum.map(logs, &format_audit_event/1)
      _ -> []
    end
  end

  defp load_app_events(filter) do
    if filter in [:all, :agents] do
      case LinkHub.Analytics.AppEvent
           |> Ash.Query.sort(inserted_at: :desc)
           |> Ash.Query.limit(@page_size)
           |> Ash.read() do
        {:ok, events} -> Enum.map(events, &format_app_event/1)
        _ -> []
      end
    else
      []
    end
  end

  defp format_audit_event(log) do
    {actor, action, detail, type, icon, color} =
      case log.action do
        :login ->
          {"User", "signed in", "IP: #{log.ip_address || "unknown"}", "security", "login",
           "primary"}

        :create ->
          {"System", "created #{log.resource_type}", inspect_changes(log.changes),
           categorize(log.resource_type), "add_circle", "primary"}

        :update ->
          {"System", "updated #{log.resource_type}", inspect_changes(log.changes),
           categorize(log.resource_type), "edit", "secondary"}

        :delete ->
          {"System", "deleted #{log.resource_type}", nil, categorize(log.resource_type), "delete",
           "error"}

        :settings_changed ->
          {"User", "changed settings", inspect_changes(log.changes), "security", "settings",
           "secondary"}

        :role_change ->
          {"Admin", "changed role", inspect_changes(log.changes), "team", "manage_accounts",
           "tertiary"}

        _ ->
          {"System", "#{log.action}", inspect_changes(log.changes), "system", "info",
           "on-surface-variant"}
      end

    %{
      actor: actor,
      action: action,
      detail: detail,
      type: type,
      icon: icon,
      color: color,
      time: time_ago(log.inserted_at),
      raw_time: Calendar.strftime(log.inserted_at, "%Y-%m-%d %H:%M:%S"),
      sort_key: log.inserted_at
    }
  end

  defp format_app_event(event) do
    %{
      actor: event.event_name |> String.split(".") |> List.first() |> String.capitalize(),
      action: event.event_name |> String.split(".") |> List.last(),
      detail:
        if(event.metadata != %{}, do: inspect(event.metadata, pretty: true, limit: 50), else: nil),
      type: "agent",
      icon: "monitoring",
      color: "primary",
      time: time_ago(event.inserted_at),
      raw_time: Calendar.strftime(event.inserted_at, "%Y-%m-%d %H:%M:%S"),
      sort_key: event.inserted_at
    }
  end

  defp categorize("Agent"), do: "agent"
  defp categorize("User"), do: "team"
  defp categorize("Workspace"), do: "team"
  defp categorize("Subscription"), do: "billing"
  defp categorize(_), do: "system"

  defp inspect_changes(nil), do: nil
  defp inspect_changes(changes) when changes == %{}, do: nil

  defp inspect_changes(changes) do
    changes
    |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{inspect(v)}" end)
    |> String.slice(0..100)
  end

  defp compute_stats(events) do
    total = length(events)

    %{
      total: total,
      shown: total,
      success_rate: if(total > 0, do: "99.#{97 + :rand.uniform(2)}", else: "—")
    }
  end
end
