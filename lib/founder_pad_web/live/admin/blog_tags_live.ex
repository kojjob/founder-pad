defmodule FounderPadWeb.Admin.BlogTagsLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    tags = load_tags(user)

    {:ok,
     assign(socket,
       page_title: "Blog Tags \u2014 Admin",
       active_nav: :admin_blog,
       tags: tags,
       new_name: "",
       editing_id: nil,
       edit_name: ""
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-4xl mx-auto">
      <%!-- Header --%>
      <div>
        <a
          href="/admin/blog"
          class="text-sm text-on-surface-variant hover:text-primary transition-colors flex items-center gap-1 mb-2"
        >
          <span class="material-symbols-outlined text-sm">arrow_back</span> Back to posts
        </a>
        <h1 class="text-3xl font-extrabold font-headline tracking-tight text-on-surface">
          Blog Tags
        </h1>
        <p class="text-on-surface-variant mt-2">
          Manage tags for your blog posts.
        </p>
      </div>

      <%!-- Create Form --%>
      <div class="bg-surface-container rounded-xl p-6">
        <h2 class="text-lg font-bold text-on-surface mb-4">Add Tag</h2>
        <form phx-submit="create" class="flex gap-3">
          <input
            type="text"
            name="name"
            value={@new_name}
            placeholder="Tag name"
            required
            class="flex-1 rounded-lg border border-outline-variant/30 px-4 py-2.5 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
          />
          <button
            type="submit"
            class="primary-gradient px-5 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95 whitespace-nowrap"
          >
            Add Tag
          </button>
        </form>
      </div>

      <%!-- Tags Table --%>
      <div class="bg-surface-container rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Name
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Slug
              </th>
              <th class="text-right px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={tag <- @tags}
              class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
            >
              <%= if @editing_id == tag.id do %>
                <td class="px-6 py-3" colspan="2">
                  <form phx-submit="update" class="flex gap-3">
                    <input type="hidden" name="tag_id" value={tag.id} />
                    <input
                      type="text"
                      name="name"
                      value={@edit_name}
                      class="flex-1 rounded-lg border border-outline-variant/30 px-3 py-2 text-sm bg-surface-container-highest focus:ring-2 focus:ring-primary/50"
                    />
                    <button
                      type="submit"
                      class="text-xs px-3 py-2 rounded-md bg-primary text-on-primary"
                    >
                      Save
                    </button>
                    <button
                      type="button"
                      phx-click="cancel-edit"
                      class="text-xs px-3 py-2 rounded-md text-on-surface-variant hover:text-on-surface"
                    >
                      Cancel
                    </button>
                  </form>
                </td>
              <% else %>
                <td class="px-6 py-4 font-medium text-on-surface">{tag.name}</td>
                <td class="px-6 py-4 text-sm text-on-surface-variant font-mono">{tag.slug}</td>
              <% end %>
              <td :if={@editing_id != tag.id} class="px-6 py-4">
                <div class="flex items-center justify-end gap-2">
                  <button
                    phx-click="edit"
                    phx-value-id={tag.id}
                    class="text-xs px-3 py-1.5 rounded-md bg-surface-container-highest text-on-surface hover:bg-primary/10 hover:text-primary transition-colors"
                  >
                    Edit
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={tag.id}
                    data-confirm="Delete this tag?"
                    class="text-xs px-3 py-1.5 rounded-md bg-red-50 text-red-700 hover:bg-red-100 transition-colors"
                  >
                    Delete
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <div
          :if={@tags == []}
          class="px-6 py-16 text-center text-on-surface-variant"
        >
          <span class="material-symbols-outlined text-4xl opacity-30 block mb-2">sell</span>
          <p>No tags yet. Create one above.</p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("create", %{"name" => name}, socket) do
    user = socket.assigns.current_user

    case FounderPad.Content.Tag
         |> Ash.Changeset.for_create(:create, %{name: name}, actor: user)
         |> Ash.create() do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> assign(tags: load_tags(user), new_name: "")
         |> put_flash(:info, "Tag created.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create tag.")}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    tag = Enum.find(socket.assigns.tags, &(&1.id == id))

    {:noreply, assign(socket, editing_id: id, edit_name: tag.name)}
  end

  def handle_event("cancel-edit", _, socket) do
    {:noreply, assign(socket, editing_id: nil)}
  end

  def handle_event("update", %{"tag_id" => id, "name" => name}, socket) do
    user = socket.assigns.current_user
    tag = Ash.get!(FounderPad.Content.Tag, id, actor: user)

    case tag
         |> Ash.Changeset.for_update(:update, %{name: name}, actor: user)
         |> Ash.update() do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(tags: load_tags(user), editing_id: nil)
         |> put_flash(:info, "Tag updated.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update tag.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    tag = Ash.get!(FounderPad.Content.Tag, id, actor: user)

    tag
    |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
    |> Ash.destroy!()

    {:noreply,
     socket
     |> assign(tags: load_tags(user))
     |> put_flash(:info, "Tag deleted.")}
  end

  defp load_tags(user) do
    FounderPad.Content.Tag
    |> Ash.Query.for_read(:read, %{}, actor: user)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(actor: user)
  end
end
