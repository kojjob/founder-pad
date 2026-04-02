defmodule FounderPadWeb.Admin.BlogCategoriesLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    categories = load_categories(user)

    {:ok,
     assign(socket,
       page_title: "Blog Categories \u2014 Admin",
       active_nav: :admin_blog,
       categories: categories,
       new_name: "",
       new_description: "",
       editing_id: nil,
       edit_name: "",
       edit_description: ""
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
          Blog Categories
        </h1>
        <p class="text-on-surface-variant mt-2">
          Organize your blog posts into categories.
        </p>
      </div>

      <%!-- Create Form --%>
      <div class="bg-surface-container rounded-xl p-6">
        <h2 class="text-lg font-bold text-on-surface mb-4">Add Category</h2>
        <form phx-submit="create" class="flex flex-col md:flex-row gap-3">
          <input
            type="text"
            name="name"
            value={@new_name}
            placeholder="Category name"
            required
            class="flex-1 rounded-lg border border-outline-variant/30 px-4 py-2.5 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
          />
          <input
            type="text"
            name="description"
            value={@new_description}
            placeholder="Description (optional)"
            class="flex-1 rounded-lg border border-outline-variant/30 px-4 py-2.5 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
          />
          <button
            type="submit"
            class="primary-gradient px-5 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95 whitespace-nowrap"
          >
            Add Category
          </button>
        </form>
      </div>

      <%!-- Categories Table --%>
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
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Posts
              </th>
              <th class="text-right px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={cat <- @categories}
              class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
            >
              <%= if @editing_id == cat.id do %>
                <td class="px-6 py-3" colspan="3">
                  <form phx-submit="update" class="flex gap-3">
                    <input type="hidden" name="category_id" value={cat.id} />
                    <input
                      type="text"
                      name="name"
                      value={@edit_name}
                      class="flex-1 rounded-lg border border-outline-variant/30 px-3 py-2 text-sm bg-surface-container-highest focus:ring-2 focus:ring-primary/50"
                    />
                    <input
                      type="text"
                      name="description"
                      value={@edit_description}
                      placeholder="Description"
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
                <td class="px-6 py-4 font-medium text-on-surface">{cat.name}</td>
                <td class="px-6 py-4 text-sm text-on-surface-variant font-mono">{cat.slug}</td>
                <td class="px-6 py-4 text-sm text-on-surface-variant">
                  {length(cat.posts || [])}
                </td>
              <% end %>
              <td :if={@editing_id != cat.id} class="px-6 py-4">
                <div class="flex items-center justify-end gap-2">
                  <button
                    phx-click="edit"
                    phx-value-id={cat.id}
                    class="text-xs px-3 py-1.5 rounded-md bg-surface-container-highest text-on-surface hover:bg-primary/10 hover:text-primary transition-colors"
                  >
                    Edit
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={cat.id}
                    data-confirm="Delete this category?"
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
          :if={@categories == []}
          class="px-6 py-16 text-center text-on-surface-variant"
        >
          <span class="material-symbols-outlined text-4xl opacity-30 block mb-2">
            category
          </span>
          <p>No categories yet. Create one above.</p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("create", %{"name" => name, "description" => description}, socket) do
    user = socket.assigns.current_user

    case FounderPad.Content.Category
         |> Ash.Changeset.for_create(:create, %{name: name, description: description}, actor: user)
         |> Ash.create() do
      {:ok, _category} ->
        {:noreply,
         socket
         |> assign(categories: load_categories(user), new_name: "", new_description: "")
         |> put_flash(:info, "Category created.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create category.")}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    cat = Enum.find(socket.assigns.categories, &(&1.id == id))

    {:noreply,
     assign(socket,
       editing_id: id,
       edit_name: cat.name,
       edit_description: cat.description || ""
     )}
  end

  def handle_event("cancel-edit", _, socket) do
    {:noreply, assign(socket, editing_id: nil)}
  end

  def handle_event("update", %{"category_id" => id, "name" => name, "description" => description}, socket) do
    user = socket.assigns.current_user
    cat = Ash.get!(FounderPad.Content.Category, id, actor: user)

    case cat
         |> Ash.Changeset.for_update(:update, %{name: name, description: description}, actor: user)
         |> Ash.update() do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(categories: load_categories(user), editing_id: nil)
         |> put_flash(:info, "Category updated.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update category.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    cat = Ash.get!(FounderPad.Content.Category, id, actor: user)

    cat
    |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
    |> Ash.destroy!()

    {:noreply,
     socket
     |> assign(categories: load_categories(user))
     |> put_flash(:info, "Category deleted.")}
  end

  defp load_categories(user) do
    FounderPad.Content.Category
    |> Ash.Query.for_read(:read, %{}, actor: user)
    |> Ash.Query.load(:posts)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(actor: user)
  end
end
