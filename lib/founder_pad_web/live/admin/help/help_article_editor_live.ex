defmodule FounderPadWeb.Admin.HelpArticleEditorLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(params, _session, socket) do
    user = socket.assigns.current_user
    categories = load_categories(user)

    case Map.get(params, "id") do
      nil ->
        {:ok,
         assign(socket,
           page_title: "New Article — Admin",
           active_nav: :admin_help,
           editing: false,
           article: nil,
           form_data: default_form_data(),
           categories: categories,
           form_errors: %{}
         )}

      id ->
        article = Ash.get!(FounderPad.HelpCenter.Article, id, actor: user)

        {:ok,
         assign(socket,
           page_title: "Edit Article — Admin",
           active_nav: :admin_help,
           editing: true,
           article: article,
           form_data: article_to_form_data(article),
           categories: categories,
           form_errors: %{}
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-8">
      <div>
        <a
          href="/admin/help"
          class="text-sm text-on-surface-variant hover:text-primary transition-colors flex items-center gap-1 mb-2"
        >
          <span class="material-symbols-outlined text-sm">arrow_back</span> Back to articles
        </a>
        <h1 class="text-3xl font-extrabold font-headline tracking-tight text-on-surface">
          {if @editing, do: "Edit Article", else: "New Article"}
        </h1>
      </div>

      <form phx-submit="save" phx-change="validate" class="space-y-8">
        <div class="bg-surface-container rounded-xl p-6 space-y-6">
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Title</label>
            <input
              type="text"
              name="article[title]"
              value={@form_data[:title]}
              phx-debounce="300"
              placeholder="Article title..."
              class={"w-full rounded-lg border px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors #{if @form_errors[:title], do: "border-red-400", else: "border-outline-variant/30"}"}
            />
            <p :if={@form_errors[:title]} class="text-red-500 text-xs mt-1">
              {@form_errors[:title]}
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Slug</label>
            <input
              type="text"
              name="article[slug]"
              value={@form_data[:slug]}
              phx-debounce="300"
              placeholder="auto-generated-slug"
              class="w-full rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors font-mono text-sm"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Category</label>
            <select
              name="article[category_id]"
              class={"w-full rounded-lg border px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors #{if @form_errors[:category_id], do: "border-red-400", else: "border-outline-variant/30"}"}
            >
              <option value="">Select a category...</option>
              <option
                :for={cat <- @categories}
                value={cat.id}
                selected={@form_data[:category_id] == cat.id}
              >
                {cat.name}
              </option>
            </select>
            <p :if={@form_errors[:category_id]} class="text-red-500 text-xs mt-1">
              {@form_errors[:category_id]}
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Excerpt</label>
            <textarea
              name="article[excerpt]"
              rows="2"
              phx-debounce="300"
              placeholder="A short summary of the article..."
              class="w-full rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors resize-none"
            >{@form_data[:excerpt]}</textarea>
          </div>

          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Body (HTML)</label>
            <textarea
              name="article[body]"
              rows="12"
              phx-debounce="300"
              placeholder="Article content (supports HTML)..."
              class={"w-full rounded-lg border px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors resize-y font-mono text-sm #{if @form_errors[:body], do: "border-red-400", else: "border-outline-variant/30"}"}
            >{@form_data[:body]}</textarea>
            <p :if={@form_errors[:body]} class="text-red-500 text-xs mt-1">
              {@form_errors[:body]}
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <label class="block text-sm font-medium text-on-surface mb-2">Status</label>
              <select
                name="article[status]"
                class="w-full rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
              >
                <option value="draft" selected={@form_data[:status] == "draft"}>Draft</option>
                <option value="published" selected={@form_data[:status] == "published"}>
                  Published
                </option>
                <option value="archived" selected={@form_data[:status] == "archived"}>
                  Archived
                </option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-on-surface mb-2">Position</label>
              <input
                type="number"
                name="article[position]"
                value={@form_data[:position]}
                min="0"
                class="w-full rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-on-surface mb-2">Context Key</label>
              <input
                type="text"
                name="article[help_context_key]"
                value={@form_data[:help_context_key]}
                phx-debounce="300"
                placeholder="e.g. billing.overview"
                class="w-full rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors font-mono text-sm"
              />
            </div>
          </div>
        </div>

        <div class="flex items-center justify-end gap-4">
          <a
            href="/admin/help"
            class="px-5 py-2.5 rounded-lg text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
          >
            Cancel
          </a>
          <button
            type="submit"
            class="primary-gradient px-6 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95"
          >
            {if @editing, do: "Update Article", else: "Create Article"}
          </button>
        </div>
      </form>
    </div>
    """
  end

  def handle_event("validate", %{"article" => params}, socket) do
    form_data = merge_form_data(socket.assigns.form_data, params)
    {:noreply, assign(socket, form_data: form_data)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"article" => params}, socket) do
    user = socket.assigns.current_user
    form_data = merge_form_data(socket.assigns.form_data, params)
    errors = validate_form(form_data)

    if map_size(errors) > 0 do
      {:noreply,
       socket
       |> assign(form_data: form_data, form_errors: errors)
       |> put_flash(:error, "Please fix the errors below.")}
    else
      ash_params =
        %{
          title: form_data[:title],
          slug: form_data[:slug],
          body: form_data[:body],
          excerpt: form_data[:excerpt],
          help_context_key: form_data[:help_context_key],
          status: String.to_existing_atom(form_data[:status] || "draft"),
          position: parse_int(form_data[:position], 0),
          category_id: form_data[:category_id]
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
        |> Map.new()

      case save_article(socket, ash_params, user) do
        {:ok, _article} ->
          {:noreply,
           socket
           |> put_flash(:info, if(socket.assigns.editing, do: "Article updated.", else: "Article created."))
           |> push_navigate(to: "/admin/help")}

        {:error, %Ash.Error.Invalid{} = error} ->
          {:noreply,
           socket
           |> assign(form_data: form_data, form_errors: changeset_to_errors(error))
           |> put_flash(:error, "Failed to save article.")}

        {:error, _error} ->
          {:noreply,
           socket
           |> assign(form_data: form_data)
           |> put_flash(:error, "Failed to save article.")}
      end
    end
  end

  defp save_article(socket, params, user) do
    if socket.assigns.editing do
      socket.assigns.article
      |> Ash.Changeset.for_update(:update, params, actor: user)
      |> Ash.update()
    else
      FounderPad.HelpCenter.Article
      |> Ash.Changeset.for_create(:create, params, actor: user)
      |> Ash.create()
    end
  end

  defp load_categories(user) do
    FounderPad.HelpCenter.Category
    |> Ash.Query.for_read(:read, %{}, actor: user)
    |> Ash.Query.sort(position: :asc)
    |> Ash.read!(actor: user)
  end

  defp default_form_data do
    %{
      title: "",
      slug: "",
      body: "",
      excerpt: "",
      status: "draft",
      position: 0,
      category_id: nil,
      help_context_key: ""
    }
  end

  defp article_to_form_data(article) do
    %{
      title: article.title || "",
      slug: article.slug || "",
      body: article.body || "",
      excerpt: article.excerpt || "",
      status: Atom.to_string(article.status),
      position: article.position || 0,
      category_id: article.category_id,
      help_context_key: article.help_context_key || ""
    }
  end

  defp merge_form_data(existing, params) do
    %{
      title: Map.get(params, "title", existing[:title]),
      slug: Map.get(params, "slug", existing[:slug]),
      body: Map.get(params, "body", existing[:body]),
      excerpt: Map.get(params, "excerpt", existing[:excerpt]),
      status: Map.get(params, "status", existing[:status]),
      position: Map.get(params, "position", existing[:position]),
      category_id: Map.get(params, "category_id", existing[:category_id]),
      help_context_key: Map.get(params, "help_context_key", existing[:help_context_key])
    }
  end

  defp validate_form(form_data) do
    errors = %{}

    errors =
      if is_nil(form_data[:title]) or String.trim(form_data[:title]) == "",
        do: Map.put(errors, :title, "Title is required"),
        else: errors

    errors =
      if is_nil(form_data[:body]) or String.trim(form_data[:body]) == "",
        do: Map.put(errors, :body, "Body is required"),
        else: errors

    errors =
      if is_nil(form_data[:category_id]) or form_data[:category_id] == "",
        do: Map.put(errors, :category_id, "Category is required"),
        else: errors

    errors
  end

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: val
  defp parse_int(_, default), do: default

  defp changeset_to_errors(%Ash.Error.Invalid{} = error) do
    error.errors
    |> Enum.map(fn e -> {e.field, e.message} end)
    |> Enum.reject(fn {k, _v} -> is_nil(k) end)
    |> Map.new()
  end

  defp changeset_to_errors(_), do: %{}
end
