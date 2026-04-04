defmodule FounderPadWeb.WidgetConfigLive do
  use FounderPadWeb, :live_view

  def mount(%{"id" => agent_id}, _session, socket) do
    case Ash.get(FounderPad.AI.Agent, agent_id) do
      {:ok, agent} ->
        host = FounderPadWeb.Endpoint.url()
        embed_code = "<script src=\"#{host}/widget/embed/#{agent.id}\"></script>"

        {:ok,
         assign(socket,
           active_nav: :agents,
           page_title: "Widget Config - #{agent.name}",
           agent: agent,
           embed_code: embed_code,
           host: host,
           widget_color: "#4648d4",
           widget_position: "bottom-right"
         )}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Agent not found") |> push_navigate(to: "/agents")}
    end
  end

  def handle_event("update_color", %{"color" => color}, socket) do
    {:noreply, assign(socket, widget_color: color)}
  end

  def handle_event("update_position", %{"position" => position}, socket) do
    {:noreply, assign(socket, widget_position: position)}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-5xl mx-auto">
      <%!-- Breadcrumbs --%>
      <div>
        <div class="flex items-center gap-2 text-sm text-on-surface-variant font-medium mb-3">
          <.link navigate="/agents" class="hover:text-on-surface transition-colors">Agents</.link>
          <span class="material-symbols-outlined text-[14px]">chevron_right</span>
          <.link navigate={"/agents/#{@agent.id}"} class="hover:text-on-surface transition-colors">{@agent.name}</.link>
          <span class="material-symbols-outlined text-[14px]">chevron_right</span>
          <span class="text-on-surface">Widget</span>
        </div>
        <h1 class="text-3xl font-extrabold font-headline tracking-tight text-on-surface">Embed Chat Widget</h1>
        <p class="text-on-surface-variant mt-1">Add a chat widget to your website powered by {@agent.name}</p>
      </div>

      <%!-- Embed Code --%>
      <div class="bg-surface-container rounded-2xl p-6 space-y-4">
        <h2 class="text-lg font-bold text-on-surface">Embed Code</h2>
        <p class="text-sm text-on-surface-variant">Copy and paste this snippet into your website's HTML, just before the closing &lt;/body&gt; tag:</p>
        <div class="relative">
          <pre class="bg-surface-container-high rounded-xl p-4 font-mono text-sm text-on-surface overflow-x-auto" id="embed-code">{@embed_code}</pre>
          <button
            phx-click={JS.dispatch("phx:copy", to: "#embed-code")}
            class="absolute top-2 right-2 px-3 py-1.5 bg-primary text-on-primary rounded-lg text-xs font-semibold hover:bg-primary/90 transition-colors"
          >
            Copy
          </button>
        </div>
      </div>

      <%!-- Customization --%>
      <div class="bg-surface-container rounded-2xl p-6 space-y-4">
        <h2 class="text-lg font-bold text-on-surface">Customization</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-semibold text-on-surface mb-2">Widget Color</label>
            <div class="flex items-center gap-3">
              <input
                type="color"
                value={@widget_color}
                phx-change="update_color"
                name="color"
                class="w-10 h-10 rounded-lg cursor-pointer border border-outline-variant"
              />
              <span class="font-mono text-sm text-on-surface-variant">{@widget_color}</span>
            </div>
          </div>
          <div>
            <label class="block text-sm font-semibold text-on-surface mb-2">Position</label>
            <div class="flex gap-2">
              <button
                phx-click="update_position"
                phx-value-position="bottom-right"
                class={[
                  "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
                  if(@widget_position == "bottom-right", do: "bg-primary text-on-primary", else: "bg-surface-container-high text-on-surface")
                ]}
              >
                Bottom Right
              </button>
              <button
                phx-click="update_position"
                phx-value-position="bottom-left"
                class={[
                  "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
                  if(@widget_position == "bottom-left", do: "bg-primary text-on-primary", else: "bg-surface-container-high text-on-surface")
                ]}
              >
                Bottom Left
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Preview --%>
      <div class="bg-surface-container rounded-2xl p-6 space-y-4">
        <h2 class="text-lg font-bold text-on-surface">Preview</h2>
        <div class="relative bg-surface-container-high rounded-xl overflow-hidden" style="height: 400px;">
          <iframe src={"/widget/chat/#{@agent.id}"} class="w-full h-full border-none rounded-xl"></iframe>
        </div>
      </div>
    </div>
    """
  end
end
