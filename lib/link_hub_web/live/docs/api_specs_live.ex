defmodule LinkHubWeb.Docs.ApiSpecsLive do
  @moduledoc "LiveView for browsing API reference documentation."
  use LinkHubWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "API Reference -- LinkHub",
       endpoints: endpoints(),
       expanded: MapSet.new(),
       active_group: nil
     ), layout: false}
  end

  def handle_event("toggle_endpoint", %{"id" => id}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded, id) do
        MapSet.delete(socket.assigns.expanded, id)
      else
        MapSet.put(socket.assigns.expanded, id)
      end

    {:noreply, assign(socket, expanded: expanded)}
  end

  def handle_event("filter_group", %{"group" => group}, socket) do
    active_group = if socket.assigns.active_group == group, do: nil, else: group
    {:noreply, assign(socket, active_group: active_group)}
  end

  defp endpoints do
    [
      %{
        id: "list-agents",
        group: "Agents",
        method: "GET",
        path: "/api/v1/agents",
        summary: "List all agents",
        description:
          "Returns a paginated list of AI agents belonging to the authenticated user. Supports filtering by provider, status, and model.",
        auth: "Bearer token",
        rate_limit: "100 requests/minute",
        request_example: """
        curl -X GET https://yourapp.com/api/v1/agents \\
          -H "Authorization: Bearer YOUR_API_TOKEN" \\
          -H "Content-Type: application/vnd.api+json"\
        """,
        response_example: """
        {
          "data": [
            {
              "id": "agent_01H8X...",
              "type": "agent",
              "attributes": {
                "name": "Research Assistant",
                "provider": "anthropic",
                "model": "claude-sonnet-4-20250514",
                "status": "active",
                "temperature": 0.7,
                "created_at": "2026-03-19T10:30:00Z"
              }
            }
          ],
          "meta": { "total": 5, "page": 1 }
        }\
        """
      },
      %{
        id: "get-agent",
        group: "Agents",
        method: "GET",
        path: "/api/v1/agents/:id",
        summary: "Get a single agent",
        description:
          "Retrieve a specific agent by ID, including its configuration, system prompt, and recent conversation history.",
        auth: "Bearer token",
        rate_limit: "100 requests/minute",
        request_example: """
        curl -X GET https://yourapp.com/api/v1/agents/agent_01H8X \\
          -H "Authorization: Bearer YOUR_API_TOKEN"\
        """,
        response_example: """
        {
          "data": {
            "id": "agent_01H8X...",
            "type": "agent",
            "attributes": {
              "name": "Research Assistant",
              "provider": "anthropic",
              "model": "claude-sonnet-4-20250514",
              "system_prompt": "You are a helpful...",
              "status": "active",
              "temperature": 0.7,
              "message_count": 142
            }
          }
        }\
        """
      },
      %{
        id: "list-plans",
        group: "Plans",
        method: "GET",
        path: "/api/v1/plans",
        summary: "List billing plans",
        description:
          "Returns all available billing plans with pricing, feature limits, and Stripe price IDs.",
        auth: "None (public)",
        rate_limit: "200 requests/minute",
        request_example: """
        curl -X GET https://yourapp.com/api/v1/plans \\
          -H "Content-Type: application/vnd.api+json"\
        """,
        response_example: """
        {
          "data": [
            {
              "id": "plan_free",
              "type": "plan",
              "attributes": {
                "name": "Free",
                "slug": "free",
                "price_monthly": 0,
                "max_agents": 1,
                "max_api_calls": 1000,
                "max_team_members": 1
              }
            },
            {
              "id": "plan_pro",
              "type": "plan",
              "attributes": {
                "name": "Pro",
                "slug": "pro",
                "price_monthly": 7900,
                "max_agents": -1,
                "max_api_calls": 100000
              }
            }
          ]
        }\
        """
      },
      %{
        id: "get-plan",
        group: "Plans",
        method: "GET",
        path: "/api/v1/plans/:id",
        summary: "Get plan details",
        description:
          "Retrieve a specific billing plan with full feature limits and pricing details.",
        auth: "None (public)",
        rate_limit: "200 requests/minute",
        request_example: """
        curl -X GET https://yourapp.com/api/v1/plans/plan_pro \\
          -H "Content-Type: application/vnd.api+json"\
        """,
        response_example: """
        {
          "data": {
            "id": "plan_pro",
            "type": "plan",
            "attributes": {
              "name": "Pro",
              "slug": "pro",
              "price_monthly": 7900,
              "max_agents": -1,
              "max_api_calls": 100000,
              "max_team_members": -1,
              "features": [
                "unlimited_agents",
                "priority_support",
                "api_access"
              ]
            }
          }
        }\
        """
      },
      %{
        id: "graphql",
        group: "GraphQL",
        method: "POST",
        path: "/api/graphql",
        summary: "GraphQL endpoint",
        description:
          "Full GraphQL API auto-derived from Ash resources. Supports queries, mutations, and subscriptions. Use GraphiQL at /api/graphiql in development.",
        auth: "Bearer token",
        rate_limit: "100 requests/minute",
        request_example: """
        curl -X POST https://yourapp.com/api/graphql \\
          -H "Authorization: Bearer YOUR_API_TOKEN" \\
          -H "Content-Type: application/json" \\
          -d '{
            "query": "{ agents { id name provider status } }"
          }'\
        """,
        response_example: """
        {
          "data": {
            "agents": [
              {
                "id": "agent_01H8X...",
                "name": "Research Assistant",
                "provider": "anthropic",
                "status": "active"
              }
            ]
          }
        }\
        """
      },
      %{
        id: "stripe-webhook",
        group: "Webhooks",
        method: "POST",
        path: "/webhooks/stripe",
        summary: "Stripe webhook receiver",
        description:
          "Receives and processes Stripe webhook events. Signature is verified using STRIPE_WEBHOOK_SECRET. Handles subscription lifecycle, payment events, and invoice updates.",
        auth: "Stripe signature (automatic)",
        rate_limit: "No limit",
        request_example: """
        # Stripe sends events automatically.
        # Configure webhook URL in Stripe Dashboard:
        # https://yourapp.com/webhooks/stripe
        #
        # Handled events:
        # checkout.session.completed
        # customer.subscription.updated
        # customer.subscription.deleted
        # invoice.payment_succeeded
        # invoice.payment_failed\
        """,
        response_example: """
        {
          "status": "ok"
        }\
        """
      },
      %{
        id: "openapi",
        group: "Meta",
        method: "GET",
        path: "/api/v1/open_api",
        summary: "OpenAPI specification",
        description:
          "Returns the full OpenAPI 3.0 specification for the REST API. Use this to generate client SDKs or import into Postman.",
        auth: "None (public)",
        rate_limit: "50 requests/minute",
        request_example: """
        curl -X GET https://yourapp.com/api/v1/open_api\
        """,
        response_example: """
        {
          "openapi": "3.0.0",
          "info": {
            "title": "LinkHub API",
            "version": "1.0.0"
          },
          "paths": { "..." },
          "components": { "..." }
        }\
        """
      },
      %{
        id: "sitemap",
        group: "Meta",
        method: "GET",
        path: "/sitemap.xml",
        summary: "XML Sitemap",
        description:
          "Auto-generated XML sitemap for search engine indexing. Includes all public pages and updates dynamically.",
        auth: "None (public)",
        rate_limit: "10 requests/minute",
        request_example: """
        curl -X GET https://yourapp.com/sitemap.xml\
        """,
        response_example: """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/...">
          <url>
            <loc>https://yourapp.com/</loc>
            <lastmod>2026-03-20</lastmod>
            <priority>1.0</priority>
          </url>
        </urlset>\
        """
      }
    ]
  end

  def render(assigns) do
    groups =
      assigns.endpoints
      |> Enum.group_by(& &1.group)
      |> Enum.sort_by(fn {group, _} ->
        Enum.find_index(["Agents", "Plans", "GraphQL", "Webhooks", "Meta"], &(&1 == group)) || 99
      end)

    assigns = assign(assigns, :groups, groups)

    ~H"""
    <div class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary">
      <.docs_nav active="api" />

      <div class="pt-20 max-w-7xl mx-auto px-6">
        <%!-- Header --%>
        <div class="py-12 mb-8">
          <h1 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight mb-3">
            API Reference
          </h1>
          <p class="text-on-surface-variant text-lg leading-relaxed max-w-2xl">
            Complete reference for the LinkHub REST and GraphQL APIs. All endpoints
            return JSON:API-compliant responses with consistent error handling.
          </p>
          <div class="flex items-center gap-3 mt-6">
            <span class="px-3 py-1.5 rounded-lg bg-surface-container text-xs font-mono text-on-surface-variant">
              Base URL: https://yourapp.com
            </span>
            <span class="px-3 py-1.5 rounded-lg bg-surface-container text-xs font-mono text-on-surface-variant">
              Format: JSON:API
            </span>
          </div>
        </div>

        <div class="flex gap-12 pb-32">
          <%!-- Sidebar --%>
          <aside class="hidden lg:block w-[200px] shrink-0">
            <nav class="sticky top-24 space-y-1">
              <p class="text-[10px] uppercase tracking-[0.2em] text-on-surface-variant/50 font-semibold mb-4">
                Endpoints
              </p>
              <%= for {group, endpoints} <- @groups do %>
                <button
                  phx-click="filter_group"
                  phx-value-group={group}
                  class={"block w-full text-left py-1.5 pl-3 text-sm transition-colors rounded-lg " <>
                    if(@active_group == group,
                      do: "text-primary font-medium bg-primary/5",
                      else: "text-on-surface-variant hover:text-on-surface"
                    )}
                >
                  {group}
                  <span class="text-on-surface-variant/40 text-xs ml-1">
                    {length(endpoints)}
                  </span>
                </button>
              <% end %>
            </nav>
          </aside>

          <%!-- Main content --%>
          <main class="flex-1 min-w-0 space-y-12">
            <%= for {group, endpoints} <- @groups do %>
              <section
                id={String.downcase(group)}
                class={if @active_group && @active_group != group, do: "hidden", else: ""}
              >
                <h2 class="text-2xl font-extrabold font-headline tracking-tight mb-6">
                  {group}
                </h2>

                <div class="space-y-4">
                  <%= for endpoint <- endpoints do %>
                    <div class="bg-surface-container rounded-xl overflow-hidden">
                      <%!-- Endpoint header (always visible) --%>
                      <button
                        phx-click="toggle_endpoint"
                        phx-value-id={endpoint.id}
                        class="w-full flex items-center gap-4 px-6 py-4 text-left hover:bg-surface-container-high/30 transition-colors cursor-pointer"
                      >
                        <.method_badge method={endpoint.method} />
                        <code class="text-sm font-mono text-on-surface flex-1">
                          {endpoint.path}
                        </code>
                        <span class="text-sm text-on-surface-variant hidden sm:block">
                          {endpoint.summary}
                        </span>
                        <span class={"material-symbols-outlined text-on-surface-variant/40 text-lg transition-transform " <>
                          if(MapSet.member?(@expanded, endpoint.id), do: "rotate-180", else: "")}>
                          expand_more
                        </span>
                      </button>

                      <%!-- Expanded details --%>
                      <%= if MapSet.member?(@expanded, endpoint.id) do %>
                        <div class="px-6 pb-6 space-y-6">
                          <div class="h-px bg-outline-variant/10"></div>

                          <p class="text-on-surface-variant leading-relaxed">
                            {endpoint.description}
                          </p>

                          <div class="flex flex-wrap gap-6 text-sm">
                            <div>
                              <span class="text-on-surface-variant/50 text-xs uppercase tracking-wider font-semibold">
                                Auth
                              </span>
                              <p class="text-on-surface mt-1 font-mono text-xs">
                                {endpoint.auth}
                              </p>
                            </div>
                            <div>
                              <span class="text-on-surface-variant/50 text-xs uppercase tracking-wider font-semibold">
                                Rate Limit
                              </span>
                              <p class="text-on-surface mt-1 font-mono text-xs">
                                {endpoint.rate_limit}
                              </p>
                            </div>
                          </div>

                          <div>
                            <h4 class="text-xs uppercase tracking-wider font-semibold text-on-surface-variant/50 mb-3">
                              Request
                            </h4>
                            <.api_code_block code={endpoint.request_example} />
                          </div>

                          <div>
                            <h4 class="text-xs uppercase tracking-wider font-semibold text-on-surface-variant/50 mb-3">
                              Response
                            </h4>
                            <.api_code_block code={endpoint.response_example} />
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </section>
            <% end %>
          </main>
        </div>
      </div>

      <.public_footer />
    </div>
    """
  end

  # -- Components --

  defp method_badge(assigns) do
    {bg, text} =
      case assigns.method do
        "GET" -> {"bg-emerald-500/10", "text-emerald-400"}
        "POST" -> {"bg-blue-500/10", "text-blue-400"}
        "PUT" -> {"bg-amber-500/10", "text-amber-400"}
        "PATCH" -> {"bg-amber-500/10", "text-amber-400"}
        "DELETE" -> {"bg-red-500/10", "text-red-400"}
        _ -> {"bg-surface-container-high", "text-on-surface-variant"}
      end

    assigns = assign(assigns, bg: bg, text: text)

    ~H"""
    <span class={"inline-flex items-center justify-center px-2.5 py-1 rounded-md text-xs font-bold font-mono min-w-[52px] " <> @bg <> " " <> @text}>
      {@method}
    </span>
    """
  end

  defp api_code_block(assigns) do
    ~H"""
    <div class="bg-[#0d1117] rounded-xl p-6 overflow-x-auto">
      <pre class="font-mono text-[13px] leading-relaxed"><code><%= format_api_code(@code) %></code></pre>
    </div>
    """
  end

  defp format_api_code(code) do
    code
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(fn line -> {:safe, colorize_line(line)} end)
    |> Enum.intersperse({:safe, "\n"})
  end

  defp colorize_line(line) do
    escaped = escape(line)
    trimmed = String.trim(line)

    cond do
      String.starts_with?(trimmed, "#") ->
        ~s[<span style="color:#8b949e">#{escaped}</span>]

      String.starts_with?(trimmed, "curl") ->
        escaped
        |> String.replace("curl", ~s[<span style="color:#79c0ff">curl</span>])
        |> then(&~s[<span style="color:#c9d1d9">#{&1}</span>])

      Regex.match?(~r/"[^"]*"/, line) ->
        Regex.replace(~r/&quot;([^&]*)&quot;/, escaped, fn _full, inner ->
          ~s[<span style="color:#a5d6ff">&quot;#{inner}&quot;</span>]
        end)
        |> then(&~s[<span style="color:#c9d1d9">#{&1}</span>])

      String.starts_with?(trimmed, "<") ->
        ~s[<span style="color:#7ee787">#{escaped}</span>]

      true ->
        ~s[<span style="color:#c9d1d9">#{escaped}</span>]
    end
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp docs_nav(assigns) do
    ~H"""
    <nav class="fixed top-0 inset-x-0 z-50 bg-background/60 backdrop-blur-md">
      <div class="max-w-7xl mx-auto flex items-center justify-between px-6 py-4">
        <a href="/" class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
            <span class="material-symbols-outlined text-on-primary text-lg">architecture</span>
          </div>
          <span class="text-xl font-extrabold font-headline tracking-tight text-on-surface">
            LinkHub
          </span>
        </a>

        <div class="hidden md:flex items-center gap-8 text-sm font-medium text-on-surface-variant">
          <a
            href="/docs"
            class={"hover:text-on-surface transition-colors " <> if(@active == "docs", do: "text-primary", else: "")}
          >
            Docs
          </a>
          <a
            href="/docs/api"
            class={"hover:text-on-surface transition-colors " <> if(@active == "api", do: "text-primary", else: "")}
          >
            API
          </a>
          <a
            href="/docs/changelog"
            class={"hover:text-on-surface transition-colors " <> if(@active == "changelog", do: "text-primary", else: "")}
          >
            Changelog
          </a>
          <a href="/auth/login" class="hover:text-on-surface transition-colors">Login</a>
        </div>

        <div class="flex items-center gap-3">
          <a
            href="/auth/register"
            class="hidden sm:inline-flex items-center px-5 py-2 rounded-lg text-sm font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95"
          >
            Get Started
          </a>
          <button
            id="theme-toggle-api"
            phx-hook="ThemeToggle"
            class="p-2 text-on-surface-variant hover:text-on-surface transition-colors cursor-pointer rounded-lg hover:bg-surface-container-high/50"
          >
            <span class="material-symbols-outlined text-xl">dark_mode</span>
          </button>
        </div>
      </div>
    </nav>
    """
  end
end
