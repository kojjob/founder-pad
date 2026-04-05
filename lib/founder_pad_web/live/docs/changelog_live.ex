defmodule FounderPadWeb.Docs.ChangelogLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    entries =
      FounderPad.Content.ChangelogEntry
      |> Ash.Query.for_read(:published)
      |> Ash.Query.load([:author])
      |> Ash.read!()

    expanded =
      entries
      |> Enum.map(& &1.version)
      |> MapSet.new()

    {:ok,
     assign(socket,
       page_title: "Changelog -- FounderPad",
       entries: entries,
       expanded: expanded
     ), layout: false}
  end

  def handle_event("toggle_release", %{"version" => version}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded, version) do
        MapSet.delete(socket.assigns.expanded, version)
      else
        MapSet.put(socket.assigns.expanded, version)
      end

    {:noreply, assign(socket, expanded: expanded)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary">
      <.docs_nav active="changelog" />

      <div class="pt-20 max-w-3xl mx-auto px-6">
        <%!-- Header --%>
        <div class="py-16 text-center">
          <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">
            Changelog
          </p>
          <h1 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight mb-4">
            What's New
          </h1>
          <p class="text-on-surface-variant text-lg leading-relaxed max-w-xl mx-auto">
            Every update, improvement, and fix shipped to FounderPad.
            Follow along as we build in public.
          </p>
        </div>

        <%!-- Timeline --%>
        <div class="relative pb-32">
          <%!-- Timeline line --%>
          <div class="absolute left-[19px] top-0 bottom-0 w-px bg-outline-variant/10 hidden sm:block">
          </div>

          <div class="space-y-8">
            <%= for entry <- @entries do %>
              <div class="relative">
                <%!-- Timeline dot --%>
                <div class="absolute left-[12px] top-7 w-[15px] h-[15px] rounded-full bg-primary/20 hidden sm:flex items-center justify-center">
                  <div class="w-[7px] h-[7px] rounded-full bg-primary"></div>
                </div>

                <%!-- Release card --%>
                <div class="sm:ml-12 bg-surface-container rounded-xl overflow-hidden">
                  <%!-- Card header --%>
                  <button
                    phx-click="toggle_release"
                    phx-value-version={entry.version}
                    class="w-full text-left px-6 py-5 flex items-start sm:items-center gap-4 hover:bg-surface-container-high/30 transition-colors cursor-pointer"
                  >
                    <div class="flex flex-col sm:flex-row sm:items-center gap-3 flex-1">
                      <span class="inline-flex items-center px-3 py-1 rounded-lg bg-primary/10 text-primary text-sm font-bold font-mono">
                        {entry.version}
                      </span>
                      <h2 class="text-lg font-bold font-headline">{entry.title}</h2>
                      <.type_badge type={entry.type} />
                      <span class="text-sm text-on-surface-variant/50">
                        {if entry.published_at,
                          do: Calendar.strftime(entry.published_at, "%B %d, %Y"),
                          else: ""}
                      </span>
                    </div>
                    <span class={"material-symbols-outlined text-on-surface-variant/40 text-lg transition-transform mt-1 " <>
                      if(MapSet.member?(@expanded, entry.version), do: "rotate-180", else: "")}>
                      expand_more
                    </span>
                  </button>

                  <%!-- Card content --%>
                  <%= if MapSet.member?(@expanded, entry.version) do %>
                    <div class="px-6 pb-6">
                      <div class="h-px bg-outline-variant/10 mb-5"></div>
                      <div class="prose prose-sm max-w-none text-on-surface prose-headings:text-on-surface prose-a:text-primary">
                        {Phoenix.HTML.raw(entry.body || "")}
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <div
            :if={@entries == []}
            class="text-center text-on-surface-variant py-16"
          >
            <p class="text-lg">No changelog entries yet. Stay tuned!</p>
          </div>
        </div>
      </div>

      <.public_footer />
    </div>
    """
  end

  # -- Components --

  defp type_badge(assigns) do
    {bg, text, label} =
      case assigns.type do
        :feature -> {"bg-primary/10", "text-primary", "Feature"}
        :fix -> {"bg-emerald-500/10", "text-emerald-400", "Fix"}
        :improvement -> {"bg-amber-500/10", "text-amber-400", "Improvement"}
        :breaking -> {"bg-red-500/10", "text-red-400", "Breaking"}
        _ -> {"bg-surface-container-high", "text-on-surface-variant", "Update"}
      end

    assigns = assign(assigns, bg: bg, text: text, label: label)

    ~H"""
    <span class={"inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider shrink-0 mt-0.5 " <> @bg <> " " <> @text}>
      {@label}
    </span>
    """
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
            FounderPad
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
            id="theme-toggle-changelog"
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
