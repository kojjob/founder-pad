defmodule FounderPadWeb.AgentTemplatesLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    templates = load_templates()
    categories = templates |> Enum.map(& &1.category) |> Enum.uniq() |> Enum.reject(&is_nil/1)

    {:ok,
     assign(socket,
       active_nav: :agents,
       page_title: "Agent Templates",
       templates: templates,
       categories: categories,
       active_category: "all"
     )}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    templates =
      if category == "all" do
        load_templates()
      else
        FounderPad.AI.AgentTemplate
        |> Ash.Query.for_read(:by_category, %{category: category}, authorize?: false)
        |> Ash.read!()
      end

    {:noreply, assign(socket, templates: templates, active_category: category)}
  end

  def handle_event("use_template", %{"id" => template_id}, socket) do
    user = socket.assigns[:current_user]
    org_id = get_user_org_id(user)

    case Ash.get(FounderPad.AI.AgentTemplate, template_id, authorize?: false) do
      {:ok, template} ->
        # Clone template into a new agent
        case FounderPad.AI.Agent
             |> Ash.Changeset.for_create(:create, %{
               name: template.name,
               description: template.description,
               system_prompt: template.system_prompt || "You are a helpful assistant.",
               model: template.model,
               provider: template.provider,
               organisation_id: org_id
             })
             |> Ash.create() do
          {:ok, agent} ->
            # Increment use count
            template
            |> Ash.Changeset.for_update(:increment_use_count, %{}, authorize?: false)
            |> Ash.update()

            {:noreply,
             socket
             |> put_flash(:info, "Agent created from template!")
             |> push_navigate(to: "/agents/#{agent.id}")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to create agent from template")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Template not found")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-7xl mx-auto">
      <div>
        <h1 class="text-3xl font-extrabold font-headline tracking-tight text-on-surface">Agent Templates</h1>
        <p class="text-on-surface-variant mt-1">Pre-built agent templates to get you started quickly</p>
      </div>

      <%!-- Category Tabs --%>
      <div class="flex gap-2 flex-wrap">
        <button
          phx-click="filter_category"
          phx-value-category="all"
          class={[
            "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
            if(@active_category == "all", do: "bg-primary text-on-primary", else: "bg-surface-container text-on-surface hover:bg-surface-container-high")
          ]}
        >
          All
        </button>
        <button
          :for={cat <- @categories}
          phx-click="filter_category"
          phx-value-category={cat}
          class={[
            "px-4 py-2 rounded-lg text-sm font-semibold transition-colors",
            if(@active_category == cat, do: "bg-primary text-on-primary", else: "bg-surface-container text-on-surface hover:bg-surface-container-high")
          ]}
        >
          {cat}
        </button>
      </div>

      <%!-- Templates Grid --%>
      <%= if @templates == [] do %>
        <div class="bg-surface-container rounded-2xl p-12 text-center">
          <span class="material-symbols-outlined text-5xl text-on-surface-variant mb-4">smart_toy</span>
          <p class="text-on-surface-variant">No templates available yet</p>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div :for={template <- @templates} class="bg-surface-container rounded-2xl p-6 hover:bg-surface-container-high transition-colors group">
            <div class="flex items-start gap-4 mb-4">
              <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                <span class="material-symbols-outlined text-2xl text-primary">{template.icon}</span>
              </div>
              <div class="flex-1 min-w-0">
                <h3 class="font-bold text-on-surface truncate">{template.name}</h3>
                <%= if template.category do %>
                  <span class="text-xs font-semibold text-on-surface-variant bg-surface-container-high px-2 py-0.5 rounded-full">{template.category}</span>
                <% end %>
              </div>
            </div>

            <p class="text-sm text-on-surface-variant mb-4 line-clamp-2">{template.description || "No description"}</p>

            <div class="flex items-center justify-between">
              <span class="text-xs text-on-surface-variant font-mono">{template.use_count} uses</span>
              <button
                phx-click="use_template"
                phx-value-id={template.id}
                class="px-4 py-2 primary-gradient rounded-lg text-sm font-semibold opacity-80 group-hover:opacity-100 transition-opacity"
              >
                Use Template
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp load_templates do
    FounderPad.AI.AgentTemplate
    |> Ash.Query.sort(use_count: :desc)
    |> Ash.read!(authorize?: false)
  end

  defp get_user_org_id(nil), do: nil
  defp get_user_org_id(user) do
    case user |> Ash.load!(:organisations) |> Map.get(:organisations) do
      [org | _] -> org.id
      _ -> nil
    end
  end
end
