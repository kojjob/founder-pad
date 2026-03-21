defmodule FounderPadWeb.WorkspacesLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]
    orgs = load_organisations(user)
    primary = List.first(orgs)
    stats = compute_stats(orgs)
    members = load_members(primary)

    {:ok,
     assign(socket,
       active_nav: :workspaces,
       page_title: "Workspace Management",
       organisations: orgs,
       primary_org: primary,
       stats: stats,
       members_count: length(members),
       sort_by: :last_active,
       show_create: false,
       create_name: ""
     )}
  end

  # ── Events ──

  def handle_event("create_workspace", %{"name" => name}, socket) when byte_size(name) > 0 do
    trimmed = String.trim(name)

    case FounderPad.Accounts.Organisation
         |> Ash.Changeset.for_create(:create, %{name: trimmed})
         |> Ash.create() do
      {:ok, org} ->
        # Link current user as owner
        if user = socket.assigns[:current_user] do
          FounderPad.Accounts.Membership
          |> Ash.Changeset.for_create(:create, %{role: :owner, user_id: user.id, organisation_id: org.id})
          |> Ash.create()
        end

        FounderPad.Audit.log(:create, "Organisation", org.id, user && user.id, org.id,
          changes: %{name: trimmed}
        )

        orgs = load_organisations(socket.assigns[:current_user])

        {:noreply,
         socket
         |> assign(organisations: orgs, primary_org: List.first(orgs), show_create: false, create_name: "")
         |> assign(stats: compute_stats(orgs))
         |> put_flash(:info, "Workspace \"#{trimmed}\" created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create workspace")}
    end
  end

  def handle_event("create_workspace", _, socket), do: {:noreply, socket}

  def handle_event("toggle_create", _, socket) do
    {:noreply, assign(socket, show_create: !socket.assigns.show_create)}
  end

  def handle_event("sort_by", %{"sort" => sort}, socket) do
    {:noreply, assign(socket, sort_by: String.to_existing_atom(sort))}
  end

  def handle_event("delete_workspace", %{"id" => id}, socket) do
    case Ash.get(FounderPad.Accounts.Organisation, id) do
      {:ok, org} ->
        case org |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy() do
          :ok ->
            orgs = load_organisations(socket.assigns[:current_user])

            {:noreply,
             socket
             |> assign(organisations: orgs, primary_org: List.first(orgs))
             |> assign(stats: compute_stats(orgs))
             |> put_flash(:info, "Workspace deleted")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete workspace")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Workspace not found")}
    end
  end

  def handle_event("export_logs", _, socket) do
    {:noreply, put_flash(socket, :info, "Audit log export started — check your email")}
  end

  # ── Render ──

  def render(assigns) do
    ~H"""
    <div class="space-y-10 max-w-6xl mx-auto">
      <%!-- Header Section --%>
      <section class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
            Workspace Management
          </h1>
          <p class="text-on-surface-variant mt-2 max-w-lg leading-relaxed">
            Manage your organisations, team permissions, and agent deployments across workspaces.
          </p>
        </div>
        <div class="flex items-center gap-3">
          <button phx-click="export_logs" class="px-4 py-2.5 rounded-lg text-sm font-medium bg-surface-container-high hover:bg-surface-container-highest transition-colors text-on-surface flex items-center gap-2">
            <span class="material-symbols-outlined text-sm">download</span> Export Logs
          </button>
          <button phx-click="toggle_create" class="primary-gradient px-4 py-2.5 rounded-lg text-sm font-medium transition-transform hover:scale-[1.02] active:scale-95 flex items-center gap-2">
            <span class="material-symbols-outlined text-sm">add</span> Create Workspace
          </button>
        </div>
      </section>

      <%!-- Create Workspace Form (inline, expandable) --%>
      <div :if={@show_create} class="bg-surface-container rounded-xl p-6">
        <h3 class="font-bold text-on-surface mb-4">New Workspace</h3>
        <form phx-submit="create_workspace" class="flex gap-3">
          <input
            type="text"
            name="name"
            value={@create_name}
            placeholder="Workspace name..."
            autofocus
            class="flex-1 bg-surface-container-highest rounded-lg px-4 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant/50 focus:ring-1 focus:ring-primary"
          />
          <button type="submit" class="primary-gradient px-6 py-2.5 rounded-lg text-sm font-semibold">Create</button>
          <button type="button" phx-click="toggle_create" class="px-4 py-2.5 rounded-lg text-sm font-medium text-on-surface-variant hover:text-on-surface">Cancel</button>
        </form>
      </div>

      <%!-- Featured Section --%>
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <%!-- Total Provisioning (Left Col) --%>
        <div class="lg:col-span-4 bg-surface-container rounded-xl p-8 flex flex-col justify-between">
          <div>
            <div class="text-xs font-bold tracking-wider text-on-surface-variant/70 uppercase mb-4">
              Total Workspaces
            </div>
            <div class="flex items-baseline gap-2">
              <span class="text-6xl font-extrabold font-headline tracking-tight text-on-surface">
                {length(@organisations)}
              </span>
              <span class="text-on-surface-variant font-medium">Active</span>
            </div>
          </div>

          <div class="mt-16">
            <div class="flex justify-between items-end mb-2">
              <span class="text-sm text-on-surface-variant">Agent Utilization</span>
              <span class="text-sm font-medium text-secondary">{@stats.agents_pct}%</span>
            </div>
            <div class="w-full bg-surface-container-highest/50 rounded-full h-1.5 overflow-hidden flex">
              <div class="bg-secondary h-full rounded-full transition-all duration-500" style={"width: #{@stats.agents_pct}%; box-shadow: 0 0 10px rgba(var(--fp-chart-secondary), 0.5);"}></div>
            </div>
          </div>
        </div>

        <%!-- Priority Workspace (Right Col) --%>
        <div class="lg:col-span-8 bg-surface-container/50 rounded-xl p-8 relative overflow-hidden">
          <div class="absolute -top-24 -right-24 w-64 h-64 bg-primary/5 rounded-full blur-3xl pointer-events-none"></div>

          <div class="flex flex-col h-full justify-between relative z-10">
            <div>
              <div class="inline-flex items-center gap-1.5 bg-primary/10 px-2.5 py-1 rounded w-max mb-5">
                <div class="w-1.5 h-1.5 rounded-full bg-primary/80"></div>
                <span class="text-[10px] uppercase font-bold tracking-wider text-primary">
                  Primary Workspace
                </span>
              </div>

              <h2 class="text-3xl font-extrabold font-headline text-on-surface mb-3">
                {if @primary_org, do: @primary_org.name, else: "No workspace yet"}
              </h2>
              <p class="text-on-surface-variant max-w-xl leading-relaxed">
                {if @primary_org, do: "Your main workspace for AI agent deployments and team collaboration.", else: "Create your first workspace to start deploying agents."}
              </p>
            </div>

            <div class="flex items-end justify-between mt-8">
              <div class="flex items-center">
                <div class="flex -space-x-2">
                  <div :for={i <- 1..min(@members_count, 3)} class="w-8 h-8 rounded-full bg-primary-fixed flex items-center justify-center text-[10px] font-bold text-primary ring-2 ring-surface-container">
                    {String.at("ABCDEFGH", i - 1)}
                  </div>
                </div>
                <div :if={@members_count > 3} class="ml-3 bg-surface-container-high px-2 py-1 rounded text-xs font-medium text-on-surface-variant">
                  +{@members_count - 3}
                </div>
              </div>

              <div class="flex gap-4">
                <div class="bg-surface-container-high/50 rounded-lg p-4 min-w-[140px]">
                  <div class="text-xs text-on-surface-variant mb-1">Agents</div>
                  <div class="text-lg font-mono font-medium text-on-surface">{@stats.agents_count}</div>
                </div>
                <div class="bg-surface-container-high/50 rounded-lg p-4 min-w-[140px]">
                  <div class="text-xs text-on-surface-variant mb-1">Members</div>
                  <div class="text-lg font-mono font-medium text-secondary">{@members_count}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- All Workspaces Section --%>
      <div class="mt-12">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-xl font-bold font-headline text-on-surface">All Workspaces</h2>
          <div class="flex items-center text-sm">
            <span class="text-on-surface-variant mr-2">Sort by:</span>
            <button phx-click="sort_by" phx-value-sort="last_active" class={["font-medium flex items-center gap-1 transition-opacity", if(@sort_by == :last_active, do: "text-on-surface", else: "text-on-surface-variant")]}>
              Last Active <span class="material-symbols-outlined text-lg">filter_list</span>
            </button>
          </div>
        </div>

        <%!-- Empty state --%>
        <div :if={@organisations == []} class="text-center py-16">
          <span class="material-symbols-outlined text-6xl text-on-surface-variant/30 mb-4 block">grid_view</span>
          <h3 class="text-xl font-bold font-headline text-on-surface mb-2">No workspaces yet</h3>
          <p class="text-on-surface-variant mb-6">Create your first workspace to organize agents and team members.</p>
          <button phx-click="toggle_create" class="primary-gradient px-6 py-2.5 rounded-lg text-sm font-semibold inline-flex items-center gap-2">
            <span class="material-symbols-outlined text-lg">add</span> Create Workspace
          </button>
        </div>

        <div class="space-y-3">
          <div
            :for={ws <- sorted_workspaces(@organisations, @sort_by)}
            class="bg-surface-container/50 hover:bg-surface-container p-5 rounded-xl transition-all flex flex-col md:flex-row md:items-center justify-between group"
          >
            <%!-- Icon + Name --%>
            <div class="flex items-center gap-4 mb-4 md:mb-0 w-full md:w-5/12">
              <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-primary/10">
                <span class="material-symbols-outlined text-primary">workspaces</span>
              </div>
              <div>
                <h3 class="font-bold text-on-surface text-base">{ws.name}</h3>
                <p class="text-xs text-on-surface-variant mt-0.5">
                  {ws.slug} • Created {Calendar.strftime(ws.inserted_at, "%b %d, %Y")}
                </p>
              </div>
            </div>

            <%!-- Status --%>
            <div class="w-full md:w-2/12 flex flex-col mb-4 md:mb-0">
              <span class="text-xs text-on-surface-variant mb-1">Status</span>
              <div class="flex items-center gap-2">
                <div class="w-2 h-2 rounded-full bg-primary animate-pulse"></div>
                <span class="text-sm font-medium text-on-surface">Active</span>
              </div>
            </div>

            <%!-- Agents --%>
            <div class="w-full md:w-2/12 flex flex-col mb-4 md:mb-0">
              <span class="text-xs text-on-surface-variant mb-1">Agents</span>
              <span class="font-mono text-sm text-on-surface">{count_org_agents(ws.id)}</span>
            </div>

            <%!-- Actions --%>
            <div class="w-full md:w-3/12 flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
              <a href="/team" class="px-3 py-1.5 rounded-lg text-xs font-medium text-primary hover:bg-primary/10 transition-colors">
                Manage Team
              </a>
              <a href="/agents" class="px-3 py-1.5 rounded-lg text-xs font-medium text-primary hover:bg-primary/10 transition-colors">
                View Agents
              </a>
              <button
                phx-click="delete_workspace"
                phx-value-id={ws.id}
                data-confirm="Delete workspace '#{ws.name}'? This cannot be undone."
                class="px-3 py-1.5 rounded-lg text-xs font-medium text-error/60 hover:text-error hover:bg-error/5 transition-colors"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Data Loaders ──

  defp load_organisations(nil), do: []

  defp load_organisations(user) do
    case FounderPad.Accounts.Membership
         |> Ash.Query.filter(user_id: user.id)
         |> Ash.Query.load([:organisation])
         |> Ash.read() do
      {:ok, memberships} ->
        memberships
        |> Enum.map(& &1.organisation)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(& &1.id)

      _ ->
        []
    end
  end

  defp load_members(nil), do: []

  defp load_members(org) do
    case FounderPad.Accounts.Membership
         |> Ash.Query.filter(organisation_id: org.id)
         |> Ash.read() do
      {:ok, members} -> members
      _ -> []
    end
  end

  defp count_org_agents(org_id) do
    case FounderPad.AI.Agent
         |> Ash.Query.filter(organisation_id: org_id)
         |> Ash.count() do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp compute_stats(orgs) do
    total_agents =
      Enum.reduce(orgs, 0, fn org, acc -> acc + count_org_agents(org.id) end)

    plan = case FounderPad.Billing.Plan |> Ash.Query.sort(sort_order: :asc) |> Ash.read() do
      {:ok, [_ | _] = plans} -> Enum.find(plans, List.first(plans), &(&1.slug == "pro"))
      _ -> nil
    end

    agents_limit = if plan, do: plan.max_agents, else: 3
    agents_pct = if agents_limit > 0, do: min(round(total_agents / agents_limit * 100), 100), else: 0

    %{
      agents_count: total_agents,
      agents_limit: agents_limit,
      agents_pct: agents_pct
    }
  end

  defp sorted_workspaces(orgs, :last_active), do: Enum.sort_by(orgs, & &1.updated_at, {:desc, DateTime})
  defp sorted_workspaces(orgs, :name), do: Enum.sort_by(orgs, & &1.name)
  defp sorted_workspaces(orgs, _), do: orgs
end
