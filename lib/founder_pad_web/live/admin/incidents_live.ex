defmodule FounderPadWeb.Admin.IncidentsLive do
  use FounderPadWeb, :live_view

  alias FounderPad.System.Incident

  require Ash.Query

  def mount(_params, _session, socket) do
    admin = socket.assigns.current_user
    incidents = load_incidents(admin)

    {:ok,
     assign(socket,
       page_title: "Incidents - Admin",
       active_nav: :admin_incidents,
       incidents: incidents,
       show_form: false,
       editing: nil,
       flash_message: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
            Incidents
          </h1>
          <p class="text-on-surface-variant mt-2">
            Manage system incidents and status updates.
          </p>
        </div>
        <button
          phx-click="show_form"
          class="inline-flex items-center gap-2 px-4 py-2 bg-primary text-on-primary rounded-lg font-medium hover:bg-primary/90 transition-colors"
        >
          <span class="material-symbols-outlined text-lg">add</span> New Incident
        </button>
      </div>

      <%= if @flash_message do %>
        <div class="bg-green-500/10 text-green-400 px-4 py-3 rounded-lg font-medium">
          {@flash_message}
        </div>
      <% end %>

      <%!-- Create/Edit Form --%>
      <%= if @show_form do %>
        <div class="bg-surface-container rounded-xl p-6">
          <h2 class="text-lg font-bold text-on-surface mb-4">
            {if @editing, do: "Edit Incident", else: "Create Incident"}
          </h2>
          <.form
            for={%{}}
            phx-submit="save_incident"
            id="incident-form"
            class="space-y-4"
          >
            <div>
              <label class="block text-sm font-medium text-on-surface mb-1">Title</label>
              <input
                type="text"
                name="incident[title]"
                value={@editing && @editing.title}
                required
                class="w-full px-4 py-2 bg-surface-container-highest text-on-surface rounded-lg border border-outline-variant/30 focus:border-primary focus:ring-1 focus:ring-primary"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-on-surface mb-1">Description</label>
              <textarea
                name="incident[description]"
                rows="3"
                class="w-full px-4 py-2 bg-surface-container-highest text-on-surface rounded-lg border border-outline-variant/30 focus:border-primary focus:ring-1 focus:ring-primary"
              ><%= @editing && @editing.description %></textarea>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-on-surface mb-1">Status</label>
                <select
                  name="incident[status]"
                  class="w-full px-4 py-2 bg-surface-container-highest text-on-surface rounded-lg border border-outline-variant/30 focus:border-primary focus:ring-1 focus:ring-primary"
                >
                  <option
                    value="investigating"
                    selected={@editing && @editing.status == :investigating}
                  >
                    Investigating
                  </option>
                  <option value="identified" selected={@editing && @editing.status == :identified}>
                    Identified
                  </option>
                  <option value="monitoring" selected={@editing && @editing.status == :monitoring}>
                    Monitoring
                  </option>
                  <option value="resolved" selected={@editing && @editing.status == :resolved}>
                    Resolved
                  </option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-on-surface mb-1">Severity</label>
                <select
                  name="incident[severity]"
                  class="w-full px-4 py-2 bg-surface-container-highest text-on-surface rounded-lg border border-outline-variant/30 focus:border-primary focus:ring-1 focus:ring-primary"
                >
                  <option value="minor" selected={@editing && @editing.severity == :minor}>
                    Minor
                  </option>
                  <option value="major" selected={@editing && @editing.severity == :major}>
                    Major
                  </option>
                  <option value="critical" selected={@editing && @editing.severity == :critical}>
                    Critical
                  </option>
                </select>
              </div>
            </div>

            <div class="flex gap-3">
              <button
                type="submit"
                class="px-4 py-2 bg-primary text-on-primary rounded-lg font-medium hover:bg-primary/90 transition-colors"
              >
                {if @editing, do: "Update", else: "Create"}
              </button>
              <button
                type="button"
                phx-click="cancel_form"
                class="px-4 py-2 bg-surface-container-highest text-on-surface rounded-lg font-medium hover:bg-surface-container-high transition-colors"
              >
                Cancel
              </button>
            </div>
          </.form>
        </div>
      <% end %>

      <%!-- Incidents Table --%>
      <div class="bg-surface-container rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Title
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Status
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Severity
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Created
              </th>
              <th class="text-center px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <%= if Enum.empty?(@incidents) do %>
              <tr>
                <td colspan="5" class="px-6 py-8 text-center text-on-surface-variant">
                  No incidents recorded
                </td>
              </tr>
            <% else %>
              <tr
                :for={incident <- @incidents}
                class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
              >
                <td class="px-6 py-4 font-medium text-on-surface">
                  {incident.title}
                </td>
                <td class="px-6 py-4">
                  <span class={[
                    "text-xs font-semibold px-2 py-0.5 rounded-full capitalize",
                    status_class(incident.status)
                  ]}>
                    {incident.status}
                  </span>
                </td>
                <td class="px-6 py-4">
                  <span class={[
                    "text-xs font-semibold px-2 py-0.5 rounded-full uppercase",
                    severity_class(incident.severity)
                  ]}>
                    {incident.severity}
                  </span>
                </td>
                <td class="px-6 py-4 text-sm text-on-surface-variant">
                  {format_time(incident.inserted_at)}
                </td>
                <td class="px-6 py-4 text-center">
                  <div class="flex items-center justify-center gap-2">
                    <button
                      phx-click="edit"
                      phx-value-id={incident.id}
                      class="text-sm text-primary hover:text-primary/80 transition-colors"
                    >
                      Edit
                    </button>
                    <%= unless incident.status == :resolved do %>
                      <button
                        phx-click="resolve"
                        phx-value-id={incident.id}
                        class="text-sm text-green-400 hover:text-green-300 transition-colors"
                      >
                        Resolve
                      </button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  def handle_event("show_form", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing: nil)}
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing: nil)}
  end

  def handle_event("save_incident", %{"incident" => params}, socket) do
    admin = socket.assigns.current_user

    result =
      if socket.assigns.editing do
        socket.assigns.editing
        |> Ash.Changeset.for_update(:update, atomize_params(params), actor: admin)
        |> Ash.update()
      else
        Incident
        |> Ash.Changeset.for_create(:create, atomize_params(params), actor: admin)
        |> Ash.create()
      end

    case result do
      {:ok, _} ->
        incidents = load_incidents(admin)

        {:noreply,
         assign(socket,
           incidents: incidents,
           show_form: false,
           editing: nil,
           flash_message:
             if(socket.assigns.editing, do: "Incident updated", else: "Incident created")
         )}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    admin = socket.assigns.current_user
    incident = Ash.get!(Incident, id, actor: admin)
    {:noreply, assign(socket, show_form: true, editing: incident)}
  end

  def handle_event("resolve", %{"id" => id}, socket) do
    admin = socket.assigns.current_user
    incident = Ash.get!(Incident, id, actor: admin)

    case incident
         |> Ash.Changeset.for_update(:resolve, %{}, actor: admin)
         |> Ash.update() do
      {:ok, _} ->
        incidents = load_incidents(admin)
        {:noreply, assign(socket, incidents: incidents, flash_message: "Incident resolved")}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp load_incidents(admin) do
    case Incident
         |> Ash.Query.for_read(:recent)
         |> Ash.read(actor: admin) do
      {:ok, incidents} -> incidents
      _ -> []
    end
  end

  defp atomize_params(params) do
    params
    |> Map.new(fn
      {"status", v} -> {:status, String.to_existing_atom(v)}
      {"severity", v} -> {:severity, String.to_existing_atom(v)}
      {k, v} -> {String.to_existing_atom(k), v}
    end)
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
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  end
end
