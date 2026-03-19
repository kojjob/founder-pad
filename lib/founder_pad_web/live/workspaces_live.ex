defmodule FounderPadWeb.WorkspacesLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_nav: :workspaces,
       page_title: "Workspaces",
       workspaces: sample_workspaces()
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <section class="flex items-end justify-between">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">Workspaces</h1>
          <p class="text-on-surface-variant mt-1">Organize agents into project workspaces</p>
        </div>
        <button class="bg-gradient-to-br from-primary to-primary-container text-on-primary-fixed font-semibold px-4 py-2 rounded-lg text-sm transition-transform active:scale-95">
          <span class="flex items-center gap-2">
            <span class="material-symbols-outlined text-lg">add</span>
            New Workspace
          </span>
        </button>
      </section>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div
          :for={ws <- @workspaces}
          class="bg-surface-container rounded-lg p-6 hover:bg-surface-container-high/50 transition-all cursor-pointer group border border-transparent hover:border-outline-variant/20"
        >
          <div class="flex items-start justify-between mb-4">
            <div class={"w-10 h-10 rounded-lg flex items-center justify-center bg-#{ws.color}/10"}>
              <span class={"material-symbols-outlined text-#{ws.color}"}>{ws.icon}</span>
            </div>
            <button class="material-symbols-outlined text-on-surface-variant opacity-0 group-hover:opacity-100 transition-opacity">
              more_vert
            </button>
          </div>
          <h3 class="font-semibold text-lg mb-1">{ws.name}</h3>
          <p class="text-sm text-on-surface-variant mb-4">{ws.description}</p>
          <div class="flex items-center justify-between text-xs font-mono text-on-surface-variant">
            <span>{ws.agents} agents</span>
            <span>{ws.last_active}</span>
          </div>
        </div>

        <%!-- New Workspace Card --%>
        <div class="bg-surface-container/30 rounded-lg p-6 border border-dashed border-outline-variant/30 flex flex-col items-center justify-center text-center hover:border-primary/30 hover:bg-surface-container/50 transition-all cursor-pointer min-h-[200px]">
          <span class="material-symbols-outlined text-3xl text-on-surface-variant/40 mb-2">
            add_circle
          </span>
          <p class="text-sm font-medium text-on-surface-variant">Create Workspace</p>
        </div>
      </div>
    </div>
    """
  end

  defp sample_workspaces do
    [
      %{
        name: "Product Research",
        description: "Customer discovery and market analysis agents",
        agents: 5,
        icon: "science",
        color: "primary",
        last_active: "2 min ago"
      },
      %{
        name: "Engineering",
        description: "Code review, documentation, and CI/CD agents",
        agents: 8,
        icon: "code",
        color: "secondary",
        last_active: "15 min ago"
      },
      %{
        name: "Marketing",
        description: "Content generation and SEO optimization",
        agents: 3,
        icon: "campaign",
        color: "primary",
        last_active: "1 hour ago"
      }
    ]
  end
end
