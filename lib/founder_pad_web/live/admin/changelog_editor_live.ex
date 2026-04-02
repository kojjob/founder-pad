defmodule FounderPadWeb.Admin.ChangelogEditorLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(params, _session, socket) do
    user = socket.assigns.current_user

    case Map.get(params, "id") do
      nil ->
        {:ok,
         assign(socket,
           page_title: "New Changelog Entry — Admin",
           active_nav: :admin_changelog,
           editing: false,
           entry: nil,
           form_data: default_form_data(),
           form_errors: %{}
         )}

      id ->
        entry = Ash.get!(FounderPad.Content.ChangelogEntry, id, actor: user)
        form_data = entry_to_form_data(entry)

        {:ok,
         assign(socket,
           page_title: "Edit Changelog Entry — Admin",
           active_nav: :admin_changelog,
           editing: true,
           entry: entry,
           form_data: form_data,
           form_errors: %{}
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-8">
      <%!-- Header --%>
      <div>
        <a
          href="/admin/changelog"
          class="text-sm text-on-surface-variant hover:text-primary transition-colors flex items-center gap-1 mb-2"
        >
          <span class="material-symbols-outlined text-sm">arrow_back</span> Back to changelog
        </a>
        <h1 class="text-3xl font-extrabold font-headline tracking-tight text-on-surface">
          {if @editing, do: "Edit Entry", else: "New Entry"}
        </h1>
      </div>

      <form phx-submit="save" phx-change="validate" class="space-y-8">
        <%!-- Main Content Card --%>
        <div class="bg-surface-container rounded-xl p-6 space-y-6">
          <%!-- Version --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Version</label>
            <input
              type="text"
              name="entry[version]"
              value={@form_data[:version]}
              phx-debounce="300"
              placeholder="v1.2.0"
              class={"w-full rounded-lg border px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors font-mono #{if @form_errors[:version], do: "border-red-400", else: "border-outline-variant/30"}"}
            />
            <p :if={@form_errors[:version]} class="text-red-500 text-xs mt-1">
              {@form_errors[:version]}
            </p>
          </div>

          <%!-- Title --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Title</label>
            <input
              type="text"
              name="entry[title]"
              value={@form_data[:title]}
              phx-debounce="300"
              placeholder="Release title..."
              class={"w-full rounded-lg border px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors #{if @form_errors[:title], do: "border-red-400", else: "border-outline-variant/30"}"}
            />
            <p :if={@form_errors[:title]} class="text-red-500 text-xs mt-1">
              {@form_errors[:title]}
            </p>
          </div>

          <%!-- Type Selector --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Type</label>
            <select
              name="entry[type]"
              class="rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
            >
              <option value="feature" selected={@form_data[:type] == "feature"}>Feature</option>
              <option value="fix" selected={@form_data[:type] == "fix"}>Fix</option>
              <option value="improvement" selected={@form_data[:type] == "improvement"}>
                Improvement
              </option>
              <option value="breaking" selected={@form_data[:type] == "breaking"}>Breaking</option>
            </select>
          </div>

          <%!-- Tiptap Editor --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Body</label>
            <div
              phx-hook="TiptapEditor"
              id="changelog-editor"
              phx-update="ignore"
              class="rounded-lg border border-outline-variant/30 bg-surface-container-highest overflow-hidden"
            >
              <div class="flex gap-1 p-2 border-b border-outline-variant/20 bg-surface-container">
                <button
                  type="button"
                  data-tiptap-action="bold"
                  class="p-1.5 rounded hover:bg-surface-container-highest transition-colors text-sm font-bold"
                >
                  B
                </button>
                <button
                  type="button"
                  data-tiptap-action="italic"
                  class="p-1.5 rounded hover:bg-surface-container-highest transition-colors text-sm italic"
                >
                  I
                </button>
                <div class="w-px bg-outline-variant/30 mx-1"></div>
                <button
                  type="button"
                  data-tiptap-action="heading"
                  data-level="2"
                  class="p-1.5 rounded hover:bg-surface-container-highest transition-colors text-sm font-bold"
                >
                  H2
                </button>
                <button
                  type="button"
                  data-tiptap-action="heading"
                  data-level="3"
                  class="p-1.5 rounded hover:bg-surface-container-highest transition-colors text-sm font-bold"
                >
                  H3
                </button>
                <div class="w-px bg-outline-variant/30 mx-1"></div>
                <button
                  type="button"
                  data-tiptap-action="bulletList"
                  class="p-1.5 rounded hover:bg-surface-container-highest transition-colors"
                >
                  <span class="material-symbols-outlined text-sm">format_list_bulleted</span>
                </button>
                <button
                  type="button"
                  data-tiptap-action="orderedList"
                  class="p-1.5 rounded hover:bg-surface-container-highest transition-colors"
                >
                  <span class="material-symbols-outlined text-sm">format_list_numbered</span>
                </button>
                <div class="w-px bg-outline-variant/30 mx-1"></div>
                <button
                  type="button"
                  data-tiptap-action="codeBlock"
                  class="p-1.5 rounded hover:bg-surface-container-highest transition-colors"
                >
                  <span class="material-symbols-outlined text-sm">code</span>
                </button>
              </div>
              <div data-tiptap-editor class="min-h-[200px] p-4 prose prose-sm max-w-none"></div>
              <textarea name="entry[body]" data-tiptap-target class="hidden">{@form_data[:body]}</textarea>
            </div>
          </div>
        </div>

        <%!-- Submit --%>
        <div class="flex items-center justify-end gap-4">
          <a
            href="/admin/changelog"
            class="px-5 py-2.5 rounded-lg text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
          >
            Cancel
          </a>
          <button
            type="submit"
            class="primary-gradient px-6 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95"
          >
            {if @editing, do: "Update Entry", else: "Create Entry"}
          </button>
        </div>
      </form>
    </div>
    """
  end

  def handle_event("validate", %{"entry" => entry_params}, socket) do
    form_data = merge_form_data(socket.assigns.form_data, entry_params)

    {:noreply,
     assign(socket,
       form_data: form_data,
       form_errors: validate_form(form_data)
     )}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"entry" => entry_params}, socket) do
    user = socket.assigns.current_user
    form_data = merge_form_data(socket.assigns.form_data, entry_params)
    errors = validate_form(form_data)

    if map_size(errors) > 0 do
      {:noreply,
       socket
       |> assign(form_data: form_data, form_errors: errors)
       |> put_flash(:error, "Please fix the errors below.")}
    else
      params = %{
        version: form_data[:version],
        title: form_data[:title],
        body: form_data[:body],
        type: String.to_existing_atom(form_data[:type] || "feature")
      }

      case save_entry(socket, params, user) do
        {:ok, _entry} ->
          {:noreply,
           socket
           |> put_flash(:info, if(socket.assigns.editing, do: "Entry updated.", else: "Entry created."))
           |> push_navigate(to: "/admin/changelog")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to save entry.")}
      end
    end
  end

  defp save_entry(socket, params, user) do
    if socket.assigns.editing do
      socket.assigns.entry
      |> Ash.Changeset.for_update(:update, params, actor: user)
      |> Ash.update()
    else
      params = Map.put(params, :author_id, user.id)

      FounderPad.Content.ChangelogEntry
      |> Ash.Changeset.for_create(:create, params, actor: user)
      |> Ash.create()
    end
  end

  defp default_form_data do
    %{
      version: "",
      title: "",
      body: "",
      type: "feature"
    }
  end

  defp entry_to_form_data(entry) do
    %{
      version: entry.version || "",
      title: entry.title || "",
      body: entry.body || "",
      type: Atom.to_string(entry.type)
    }
  end

  defp merge_form_data(existing, params) do
    %{
      version: Map.get(params, "version", existing[:version]),
      title: Map.get(params, "title", existing[:title]),
      body: Map.get(params, "body", existing[:body]),
      type: Map.get(params, "type", existing[:type])
    }
  end

  defp validate_form(form_data) do
    errors = %{}

    errors =
      if is_nil(form_data[:title]) or String.trim(form_data[:title]) == "" do
        Map.put(errors, :title, "Title is required")
      else
        errors
      end

    errors =
      if is_nil(form_data[:version]) or String.trim(form_data[:version]) == "" do
        Map.put(errors, :version, "Version is required")
      else
        errors
      end

    errors
  end
end
