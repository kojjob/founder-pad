defmodule FounderPadWeb.Admin.AgentTemplatesLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    templates = load_templates()

    {:ok,
     assign(socket,
       active_nav: :admin,
       page_title: "Manage Agent Templates",
       templates: templates,
       editing: nil,
       form: default_form()
     )}
  end

  def handle_event("new", _, socket) do
    {:noreply, assign(socket, editing: :new, form: default_form())}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    case Ash.get(FounderPad.AI.AgentTemplate, id, authorize?: false) do
      {:ok, template} ->
        form = %{
          "name" => template.name,
          "description" => template.description || "",
          "category" => template.category || "",
          "system_prompt" => template.system_prompt || "",
          "model" => template.model || "claude-sonnet-4-20250514",
          "provider" => to_string(template.provider),
          "icon" => template.icon || "smart_toy",
          "featured" => template.featured
        }

        {:noreply, assign(socket, editing: template.id, form: form)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Template not found")}
    end
  end

  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, editing: nil)}
  end

  def handle_event("save", %{"template" => params}, socket) do
    admin = socket.assigns[:current_user]

    result =
      if socket.assigns.editing == :new do
        FounderPad.AI.AgentTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: params["name"],
          description: params["description"],
          category: params["category"],
          system_prompt: params["system_prompt"],
          model: params["model"],
          provider: String.to_existing_atom(params["provider"] || "anthropic"),
          icon: params["icon"],
          featured: params["featured"] == "true"
        }, actor: admin)
        |> Ash.create()
      else
        case Ash.get(FounderPad.AI.AgentTemplate, socket.assigns.editing, authorize?: false) do
          {:ok, template} ->
            template
            |> Ash.Changeset.for_update(:update, %{
              name: params["name"],
              description: params["description"],
              category: params["category"],
              system_prompt: params["system_prompt"],
              model: params["model"],
              provider: String.to_existing_atom(params["provider"] || "anthropic"),
              icon: params["icon"],
              featured: params["featured"] == "true"
            }, actor: admin)
            |> Ash.update()

          error -> error
        end
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(templates: load_templates(), editing: nil)
         |> put_flash(:info, "Template saved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save template")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    admin = socket.assigns[:current_user]

    case Ash.get(FounderPad.AI.AgentTemplate, id, authorize?: false) do
      {:ok, template} ->
        case template |> Ash.Changeset.for_destroy(:destroy, actor: admin) |> Ash.destroy() do
          :ok ->
            {:noreply,
             socket
             |> assign(templates: load_templates())
             |> put_flash(:info, "Template deleted")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete template")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Template not found")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-extrabold font-headline tracking-tight text-on-surface">Agent Templates</h1>
          <p class="text-on-surface-variant mt-1">Manage marketplace templates</p>
        </div>
        <button phx-click="new" class="px-5 py-2.5 primary-gradient rounded-lg text-sm font-semibold flex items-center gap-2">
          <span class="material-symbols-outlined text-lg">add</span> New Template
        </button>
      </div>

      <%!-- Editor Form --%>
      <%= if @editing do %>
        <div class="bg-surface-container rounded-2xl p-6">
          <h2 class="text-lg font-bold text-on-surface mb-4">{if @editing == :new, do: "Create Template", else: "Edit Template"}</h2>
          <form phx-submit="save" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-semibold text-on-surface mb-1">Name</label>
                <input type="text" name="template[name]" value={@form["name"]} required class="w-full px-3 py-2 bg-surface-container-high border border-outline-variant rounded-lg text-on-surface" />
              </div>
              <div>
                <label class="block text-sm font-semibold text-on-surface mb-1">Category</label>
                <input type="text" name="template[category]" value={@form["category"]} class="w-full px-3 py-2 bg-surface-container-high border border-outline-variant rounded-lg text-on-surface" />
              </div>
              <div>
                <label class="block text-sm font-semibold text-on-surface mb-1">Icon</label>
                <input type="text" name="template[icon]" value={@form["icon"]} class="w-full px-3 py-2 bg-surface-container-high border border-outline-variant rounded-lg text-on-surface" />
              </div>
              <div>
                <label class="block text-sm font-semibold text-on-surface mb-1">Model</label>
                <input type="text" name="template[model]" value={@form["model"]} class="w-full px-3 py-2 bg-surface-container-high border border-outline-variant rounded-lg text-on-surface" />
              </div>
              <div>
                <label class="block text-sm font-semibold text-on-surface mb-1">Provider</label>
                <select name="template[provider]" class="w-full px-3 py-2 bg-surface-container-high border border-outline-variant rounded-lg text-on-surface">
                  <option value="anthropic" selected={@form["provider"] == "anthropic"}>Anthropic</option>
                  <option value="openai" selected={@form["provider"] == "openai"}>OpenAI</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-semibold text-on-surface mb-1">Featured</label>
                <select name="template[featured]" class="w-full px-3 py-2 bg-surface-container-high border border-outline-variant rounded-lg text-on-surface">
                  <option value="true" selected={@form["featured"] == true}>Yes</option>
                  <option value="false" selected={@form["featured"] != true}>No</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-semibold text-on-surface mb-1">Description</label>
              <textarea name="template[description]" rows="2" class="w-full px-3 py-2 bg-surface-container-high border border-outline-variant rounded-lg text-on-surface">{@form["description"]}</textarea>
            </div>
            <div>
              <label class="block text-sm font-semibold text-on-surface mb-1">System Prompt</label>
              <textarea name="template[system_prompt]" rows="4" class="w-full px-3 py-2 bg-surface-container-high border border-outline-variant rounded-lg text-on-surface font-mono text-sm">{@form["system_prompt"]}</textarea>
            </div>
            <div class="flex gap-3">
              <button type="submit" class="px-5 py-2.5 primary-gradient rounded-lg text-sm font-semibold">Save</button>
              <button type="button" phx-click="cancel" class="px-5 py-2.5 bg-surface-container-high hover:bg-surface-container-highest text-on-surface rounded-lg text-sm font-semibold">Cancel</button>
            </div>
          </form>
        </div>
      <% end %>

      <%!-- Templates Table --%>
      <div class="bg-surface-container rounded-2xl p-6">
        <%= if @templates == [] do %>
          <p class="text-on-surface-variant text-sm">No templates yet. Create one above.</p>
        <% else %>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-outline-variant text-left">
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">Name</th>
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">Category</th>
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">Uses</th>
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">Featured</th>
                  <th class="py-3 px-4 text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={t <- @templates} class="border-b border-outline-variant/50 hover:bg-surface-container-high transition-colors">
                  <td class="py-3 px-4 font-semibold text-on-surface">{t.name}</td>
                  <td class="py-3 px-4 text-on-surface-variant">{t.category || "-"}</td>
                  <td class="py-3 px-4 font-mono text-on-surface">{t.use_count}</td>
                  <td class="py-3 px-4">{if t.featured, do: "Yes", else: "No"}</td>
                  <td class="py-3 px-4 flex gap-2">
                    <button phx-click="edit" phx-value-id={t.id} class="text-primary hover:underline text-sm">Edit</button>
                    <button phx-click="delete" phx-value-id={t.id} data-confirm="Delete this template?" class="text-error hover:underline text-sm">Delete</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp load_templates do
    FounderPad.AI.AgentTemplate
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  defp default_form do
    %{
      "name" => "",
      "description" => "",
      "category" => "",
      "system_prompt" => "",
      "model" => "claude-sonnet-4-20250514",
      "provider" => "anthropic",
      "icon" => "smart_toy",
      "featured" => false
    }
  end
end
