defmodule FounderPadWeb.AuditLogLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  @page_size 50

  @action_types ~w(create update delete login logout invite role_change subscription_change api_key_created api_key_revoked settings_changed export_requested)

  def mount(_params, _session, socket) do
    logs = load_logs(%{})

    {:ok,
     assign(socket,
       active_nav: :activity,
       page_title: "Audit Log",
       logs: logs,
       filters: %{},
       expanded_id: nil,
       search_query: ""
     )}
  end

  def handle_event("filter", %{"action" => action}, socket) do
    filters = Map.put(socket.assigns.filters, :action, String.to_existing_atom(action))
    logs = load_logs(filters, socket.assigns.search_query)
    {:noreply, assign(socket, filters: filters, logs: logs)}
  end

  def handle_event("filter_resource", %{"resource_type" => resource_type}, socket) do
    filters = Map.put(socket.assigns.filters, :resource_type, resource_type)
    logs = load_logs(filters, socket.assigns.search_query)
    {:noreply, assign(socket, filters: filters, logs: logs)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    logs = load_logs(socket.assigns.filters, query)
    {:noreply, assign(socket, search_query: query, logs: logs)}
  end

  def handle_event("search", %{"value" => query}, socket) do
    logs = load_logs(socket.assigns.filters, query)
    {:noreply, assign(socket, search_query: query, logs: logs)}
  end

  def handle_event("clear_filters", _, socket) do
    logs = load_logs(%{})
    {:noreply, assign(socket, filters: %{}, logs: logs, search_query: "")}
  end

  def handle_event("toggle_details", %{"id" => id}, socket) do
    new_id = if socket.assigns.expanded_id == id, do: nil, else: id
    {:noreply, assign(socket, expanded_id: new_id)}
  end

  def handle_event("export_csv", _, socket) do
    logs = load_logs(socket.assigns.filters, socket.assigns.search_query, :all)
    csv = build_csv(logs)

    {:noreply, push_event(socket, "download", %{data: csv, filename: "audit_log.csv", content_type: "text/csv"})}
  end

  def handle_event("refresh", _, socket) do
    logs = load_logs(socket.assigns.filters, socket.assigns.search_query)

    {:noreply,
     socket
     |> assign(logs: logs)
     |> put_flash(:info, "Audit log refreshed")}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8" id="audit-log" phx-hook="DownloadHook">
      <%!-- Header --%>
      <section class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <div class="flex items-center gap-2 text-xs font-mono text-on-surface-variant/60 uppercase tracking-widest mb-2">
            <span class="material-symbols-outlined text-sm text-primary">shield</span>
            Compliance
          </div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">Audit Log</h1>
          <p class="text-on-surface-variant mt-1">Immutable record of all system actions for compliance and security review.</p>
        </div>
        <div class="flex items-center gap-3">
          <button phx-click="export_csv" class="px-4 py-2 text-sm font-medium rounded-lg bg-surface-container-high text-on-surface hover:bg-surface-container-highest transition-colors flex items-center gap-2">
            <span class="material-symbols-outlined text-sm">download</span>
            Export CSV
          </button>
          <button phx-click="refresh" class="p-2 text-on-surface-variant hover:text-primary rounded-lg hover:bg-surface-container-high transition-colors" title="Refresh">
            <span class="material-symbols-outlined">refresh</span>
          </button>
        </div>
      </section>

      <%!-- Filter Bar --%>
      <section class="bg-surface-container rounded-lg p-4 space-y-4">
        <div class="flex items-center gap-2 mb-2">
          <span class="material-symbols-outlined text-sm text-on-surface-variant">filter_list</span>
          <span class="text-sm font-medium text-on-surface-variant">Filter</span>
          <button
            :if={@filters != %{} or @search_query != ""}
            phx-click="clear_filters"
            class="ml-auto text-xs text-primary hover:underline"
          >
            Clear all
          </button>
        </div>

        <div class="flex flex-wrap gap-3">
          <%!-- Action Type Filter --%>
          <div class="flex flex-wrap gap-1.5">
            <button
              :for={action <- action_types()}
              phx-click="filter"
              phx-value-action={action}
              class={[
                "px-2.5 py-1 text-xs font-medium rounded-md transition-colors",
                if(Map.get(@filters, :action) == String.to_existing_atom(action),
                  do: "bg-primary text-on-primary",
                  else: "bg-surface-container-high text-on-surface-variant hover:text-on-surface"
                )
              ]}
            >
              {action}
            </button>
          </div>
        </div>

        <%!-- Search --%>
        <div class="flex gap-3">
          <div class="flex-1 relative">
            <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-sm">search</span>
            <input
              type="text"
              placeholder="Search by resource type, IP address..."
              value={@search_query}
              phx-keyup="search"
              phx-key="Enter"
              phx-value-query={@search_query}
              class="w-full pl-9 pr-4 py-2 text-sm bg-surface-container-high rounded-lg border-0 text-on-surface placeholder-on-surface-variant/50 focus:ring-1 focus:ring-primary"
              name="query"
            />
          </div>
        </div>

        <%!-- Active Filters Display --%>
        <div :if={@filters != %{}} class="flex flex-wrap gap-2">
          <span
            :for={{key, val} <- @filters}
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-primary/10 text-primary text-xs font-medium"
          >
            {key}: {val}
            <button phx-click="clear_filters" class="ml-1 hover:text-on-primary">&times;</button>
          </span>
        </div>
      </section>

      <%!-- Resource Type Quick Filters --%>
      <div class="flex gap-2 flex-wrap">
        <button
          :for={rt <- ["Agent", "User", "Organisation", "Subscription", "Session"]}
          phx-click="filter_resource"
          phx-value-resource_type={rt}
          class={[
            "px-3 py-1 text-xs font-medium rounded-md transition-colors",
            if(Map.get(@filters, :resource_type) == rt,
              do: "bg-primary text-on-primary",
              else: "bg-surface-container text-on-surface-variant hover:text-on-surface"
            )
          ]}
        >
          {rt}
        </button>
      </div>

      <%!-- Empty State --%>
      <div :if={@logs == []} class="text-center py-16">
        <span class="material-symbols-outlined text-6xl text-on-surface-variant/30 mb-4 block">shield</span>
        <h3 class="text-xl font-bold font-headline text-on-surface mb-2">No audit logs found</h3>
        <p class="text-on-surface-variant">
          {if @filters != %{} or @search_query != "", do: "Try adjusting your filters or search query.", else: "Audit events will appear here as actions are performed."}
        </p>
      </div>

      <%!-- Log Entries --%>
      <div :if={@logs != []} class="space-y-2">
        <div
          :for={log <- @logs}
          class="bg-surface-container rounded-lg overflow-hidden"
        >
          <%!-- Log Row --%>
          <button
            phx-click="toggle_details"
            phx-value-id={log.id}
            class="w-full px-6 py-3 flex items-center gap-4 hover:bg-surface-container-high/50 transition-colors text-left"
          >
            <div class={"w-8 h-8 rounded flex items-center justify-center shrink-0 #{action_bg(log.action)}"}>
              <span class={"material-symbols-outlined text-sm #{action_text(log.action)}"}>{action_icon(log.action)}</span>
            </div>
            <div class="flex-1 min-w-0 grid grid-cols-12 gap-2 items-center">
              <div class="col-span-2">
                <span class={["px-1.5 py-0.5 rounded text-[10px] font-bold uppercase", action_badge(log.action)]}>
                  {log.action}
                </span>
              </div>
              <div class="col-span-2 text-sm font-medium text-on-surface truncate">{log.resource_type}</div>
              <div class="col-span-3 text-xs font-mono text-on-surface-variant truncate">{short_id(log.resource_id)}</div>
              <div class="col-span-2 text-xs text-on-surface-variant">{log.ip_address || "—"}</div>
              <div class="col-span-3 text-xs font-mono text-on-surface-variant">{format_time(log.inserted_at)}</div>
            </div>
            <span class="material-symbols-outlined text-on-surface-variant text-sm shrink-0">
              {if @expanded_id == log.id, do: "expand_less", else: "expand_more"}
            </span>
          </button>

          <%!-- Expanded Details --%>
          <div :if={@expanded_id == log.id} class="border-t border-outline-variant/20 px-6 py-4 space-y-4 bg-surface-container-high/20">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <p class="text-xs font-mono text-on-surface-variant uppercase mb-1">Actor ID</p>
                <p class="text-sm font-mono">{log.actor_id || "System"}</p>
              </div>
              <div>
                <p class="text-xs font-mono text-on-surface-variant uppercase mb-1">Organisation ID</p>
                <p class="text-sm font-mono">{log.organisation_id || "—"}</p>
              </div>
              <div>
                <p class="text-xs font-mono text-on-surface-variant uppercase mb-1">IP Address</p>
                <p class="text-sm font-mono">{log.ip_address || "—"}</p>
              </div>
              <div>
                <p class="text-xs font-mono text-on-surface-variant uppercase mb-1">User Agent</p>
                <p class="text-sm font-mono truncate">{log.user_agent || "—"}</p>
              </div>
            </div>

            <div :if={log.changes && log.changes != %{}}>
              <p class="text-xs font-mono text-on-surface-variant uppercase mb-1">Changes</p>
              <pre class="text-xs font-mono text-on-surface bg-surface-container-highest/30 rounded p-3 overflow-x-auto">{format_json(log.changes)}</pre>
            </div>

            <div :if={log.metadata && log.metadata != %{}}>
              <p class="text-xs font-mono text-on-surface-variant uppercase mb-1">Metadata</p>
              <pre class="text-xs font-mono text-on-surface bg-surface-container-highest/30 rounded p-3 overflow-x-auto">{format_json(log.metadata)}</pre>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ──

  defp action_types, do: @action_types

  defp action_icon(:create), do: "add_circle"
  defp action_icon(:update), do: "edit"
  defp action_icon(:delete), do: "delete"
  defp action_icon(:login), do: "login"
  defp action_icon(:logout), do: "logout"
  defp action_icon(:invite), do: "person_add"
  defp action_icon(:role_change), do: "manage_accounts"
  defp action_icon(:settings_changed), do: "settings"
  defp action_icon(:api_key_created), do: "key"
  defp action_icon(:api_key_revoked), do: "key_off"
  defp action_icon(_), do: "info"

  defp action_bg(:delete), do: "bg-error/10"
  defp action_bg(:login), do: "bg-primary/10"
  defp action_bg(:logout), do: "bg-on-surface-variant/10"
  defp action_bg(_), do: "bg-secondary/10"

  defp action_text(:delete), do: "text-error"
  defp action_text(:login), do: "text-primary"
  defp action_text(:logout), do: "text-on-surface-variant"
  defp action_text(_), do: "text-secondary"

  defp action_badge(:create), do: "bg-primary/10 text-primary"
  defp action_badge(:update), do: "bg-secondary/10 text-secondary"
  defp action_badge(:delete), do: "bg-error/10 text-error"
  defp action_badge(:login), do: "bg-primary/10 text-primary"
  defp action_badge(_), do: "bg-on-surface-variant/10 text-on-surface-variant"

  defp short_id(id) when byte_size(id) > 12, do: String.slice(id, 0..11) <> "..."
  defp short_id(id), do: id

  defp format_time(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end

  defp format_json(nil), do: "{}"
  defp format_json(map) when map == %{}, do: "{}"
  defp format_json(map), do: Jason.encode!(map, pretty: true)

  # ── Data Loading ──

  defp load_logs(filters, search_query \\ "", limit \\ :default) do
    query =
      FounderPad.Audit.AuditLog
      |> Ash.Query.sort(inserted_at: :desc)

    query =
      case limit do
        :all -> query
        _ -> Ash.Query.limit(query, @page_size)
      end

    query = apply_filters(query, filters)
    query = apply_search(query, search_query)

    case Ash.read(query) do
      {:ok, logs} -> logs
      _ -> []
    end
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:action, action}, q -> Ash.Query.filter(q, action == ^action)
      {:resource_type, resource_type}, q -> Ash.Query.filter(q, resource_type == ^resource_type)
      _, q -> q
    end)
  end

  defp apply_search(query, "") do
    query
  end

  defp apply_search(query, search_query) do
    Ash.Query.filter(query, contains(resource_type, ^search_query))
  end

  defp build_csv(logs) do
    header = "timestamp,action,resource_type,resource_id,actor_id,organisation_id,ip_address,user_agent,changes,metadata\n"

    rows =
      Enum.map(logs, fn log ->
        [
          format_time(log.inserted_at),
          to_string(log.action),
          log.resource_type,
          log.resource_id,
          log.actor_id || "",
          log.organisation_id || "",
          log.ip_address || "",
          csv_escape(log.user_agent || ""),
          csv_escape(Jason.encode!(log.changes || %{})),
          csv_escape(Jason.encode!(log.metadata || %{}))
        ]
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    header <> rows
  end

  defp csv_escape(str) do
    if String.contains?(str, [",", "\"", "\n"]) do
      "\"" <> String.replace(str, "\"", "\"\"") <> "\""
    else
      str
    end
  end
end
