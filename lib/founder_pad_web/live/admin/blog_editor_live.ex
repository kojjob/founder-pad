defmodule FounderPadWeb.Admin.BlogEditorLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  import FounderPadWeb.BlogComponents, only: [seo_score_badge: 1]

  alias FounderPad.Content.SeoScorer

  def mount(params, _session, socket) do
    user = socket.assigns.current_user
    categories = load_categories(user)
    tags = load_tags(user)

    case Map.get(params, "id") do
      nil ->
        {:ok,
         socket
         |> assign(
           page_title: "New Post \u2014 Admin",
           active_nav: :admin_blog,
           editing: false,
           post: nil,
           form_data: default_form_data(),
           categories: categories,
           tags: tags,
           selected_category_ids: MapSet.new(),
           selected_tag_ids: MapSet.new(),
           seo_result: SeoScorer.score(default_form_data()),
           form_errors: %{}
         )
         |> allow_upload(:featured_image,
           accept: ~w(.jpg .jpeg .png .gif .webp),
           max_entries: 1,
           max_file_size: 5_000_000
         )}

      id ->
        post =
          FounderPad.Content.Post
          |> Ash.get!(id, actor: user, load: [:author, :categories, :tags])

        form_data = post_to_form_data(post)
        selected_cat_ids = MapSet.new(post.categories, & &1.id)
        selected_tag_ids = MapSet.new(post.tags, & &1.id)

        {:ok,
         socket
         |> assign(
           page_title: "Edit Post \u2014 Admin",
           active_nav: :admin_blog,
           editing: true,
           post: post,
           form_data: form_data,
           categories: categories,
           tags: tags,
           selected_category_ids: selected_cat_ids,
           selected_tag_ids: selected_tag_ids,
           seo_result: SeoScorer.score(form_data),
           form_errors: %{}
         )
         |> allow_upload(:featured_image,
           accept: ~w(.jpg .jpeg .png .gif .webp),
           max_entries: 1,
           max_file_size: 5_000_000
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-8">
      <%!-- Header --%>
      <div class="flex items-center justify-between">
        <div>
          <a
            href="/admin/blog"
            class="text-sm text-on-surface-variant hover:text-primary transition-colors flex items-center gap-1 mb-2"
          >
            <span class="material-symbols-outlined text-sm">arrow_back</span> Back to posts
          </a>
          <h1 class="text-3xl font-extrabold font-headline tracking-tight text-on-surface">
            {if @editing, do: "Edit Post", else: "New Post"}
          </h1>
        </div>
        <.seo_score_badge score={@seo_result.score} />
      </div>

      <form phx-submit="save" phx-change="validate" class="space-y-8">
        <%!-- Main Content Card --%>
        <div class="bg-surface-container rounded-xl p-6 space-y-6">
          <%!-- Title --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Title</label>
            <input
              type="text"
              name="post[title]"
              value={@form_data[:title]}
              phx-debounce="300"
              placeholder="Enter post title..."
              class={"w-full rounded-lg border px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors #{if @form_errors[:title], do: "border-red-400", else: "border-outline-variant/30"}"}
            />
            <p :if={@form_errors[:title]} class="text-red-500 text-xs mt-1">
              {@form_errors[:title]}
            </p>
          </div>

          <%!-- Slug --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Slug</label>
            <div class="flex items-center gap-2">
              <span class="text-sm text-on-surface-variant">/blog/</span>
              <input
                type="text"
                name="post[slug]"
                value={@form_data[:slug]}
                phx-debounce="300"
                placeholder="auto-generated-slug"
                class="flex-1 rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors font-mono text-sm"
              />
            </div>
          </div>

          <%!-- Excerpt --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Excerpt</label>
            <textarea
              name="post[excerpt]"
              rows="3"
              phx-debounce="300"
              placeholder="A short summary of the post..."
              class="w-full rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors resize-none"
            >{@form_data[:excerpt]}</textarea>
          </div>

          <%!-- Status --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Status</label>
            <select
              name="post[status]"
              class="rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
            >
              <option value="draft" selected={@form_data[:status] == "draft"}>Draft</option>
              <option value="published" selected={@form_data[:status] == "published"}>
                Published
              </option>
              <option value="scheduled" selected={@form_data[:status] == "scheduled"}>
                Scheduled
              </option>
              <option value="archived" selected={@form_data[:status] == "archived"}>
                Archived
              </option>
            </select>
          </div>

          <%!-- Tiptap Editor --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Body</label>
            <div
              phx-hook="TiptapEditor"
              id="post-editor"
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
                <button
                  type="button"
                  data-tiptap-action="strike"
                  class="p-1.5 rounded hover:bg-surface-container-highest transition-colors text-sm line-through"
                >
                  S
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
                  data-tiptap-action="blockquote"
                  class="p-1.5 rounded hover:bg-surface-container-highest transition-colors"
                >
                  <span class="material-symbols-outlined text-sm">format_quote</span>
                </button>
                <button
                  type="button"
                  data-tiptap-action="codeBlock"
                  class="p-1.5 rounded hover:bg-surface-container-highest transition-colors"
                >
                  <span class="material-symbols-outlined text-sm">code</span>
                </button>
              </div>
              <div data-tiptap-editor class="min-h-[300px] p-4 prose prose-sm max-w-none"></div>
              <textarea name="post[body]" data-tiptap-target class="hidden">{@form_data[:body]}</textarea>
            </div>
          </div>
        </div>

        <%!-- Categories & Tags Card --%>
        <div class="bg-surface-container rounded-xl p-6 space-y-6">
          <h2 class="text-lg font-bold text-on-surface">Categories & Tags</h2>

          <%!-- Categories --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-3">Categories</label>
            <div class="flex flex-wrap gap-2">
              <label
                :for={cat <- @categories}
                class={"flex items-center gap-2 px-3 py-1.5 rounded-lg border cursor-pointer transition-colors #{if MapSet.member?(@selected_category_ids, cat.id), do: "border-primary bg-primary/10 text-primary", else: "border-outline-variant/30 text-on-surface-variant hover:border-primary/50"}"}
              >
                <input
                  type="checkbox"
                  name="post[category_ids][]"
                  value={cat.id}
                  checked={MapSet.member?(@selected_category_ids, cat.id)}
                  class="sr-only"
                />
                {cat.name}
              </label>
            </div>
          </div>

          <%!-- Tags --%>
          <div>
            <label class="block text-sm font-medium text-on-surface mb-3">Tags</label>
            <div class="flex flex-wrap gap-2">
              <label
                :for={tag <- @tags}
                class={"flex items-center gap-2 px-3 py-1.5 rounded-lg border cursor-pointer transition-colors #{if MapSet.member?(@selected_tag_ids, tag.id), do: "border-primary bg-primary/10 text-primary", else: "border-outline-variant/30 text-on-surface-variant hover:border-primary/50"}"}
              >
                <input
                  type="checkbox"
                  name="post[tag_ids][]"
                  value={tag.id}
                  checked={MapSet.member?(@selected_tag_ids, tag.id)}
                  class="sr-only"
                />
                {tag.name}
              </label>
            </div>
          </div>
        </div>

        <%!-- Featured Image Card --%>
        <div class="bg-surface-container rounded-xl p-6 space-y-4">
          <h2 class="text-lg font-bold text-on-surface">Featured Image</h2>

          <div class="flex items-start gap-6">
            <div class="flex-1">
              <.live_file_input upload={@uploads.featured_image} class="text-sm" />
              <p class="text-xs text-on-surface-variant mt-2">
                JPG, PNG, GIF, or WebP. Max 5MB.
              </p>
            </div>
            <div
              :if={@form_data[:featured_image_url]}
              class="w-32 h-20 rounded-lg overflow-hidden border border-outline-variant/30"
            >
              <img
                src={@form_data[:featured_image_url]}
                alt="Featured"
                class="w-full h-full object-cover"
              />
            </div>
          </div>

          <%= for entry <- @uploads.featured_image.entries do %>
            <div class="flex items-center gap-3">
              <.live_img_preview entry={entry} class="w-20 h-12 rounded object-cover" />
              <div class="flex-1">
                <div class="text-sm text-on-surface">{entry.client_name}</div>
                <div class="w-full bg-surface-container-highest rounded-full h-1.5 mt-1">
                  <div
                    class="bg-primary h-1.5 rounded-full transition-all"
                    style={"width: #{entry.progress}%"}
                  >
                  </div>
                </div>
              </div>
              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                class="text-red-500 hover:text-red-700"
              >
                <span class="material-symbols-outlined text-sm">close</span>
              </button>
            </div>
          <% end %>
        </div>

        <%!-- SEO Fields Card --%>
        <div class="bg-surface-container rounded-xl p-6 space-y-6">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-bold text-on-surface">SEO Settings</h2>
            <.seo_score_badge score={@seo_result.score} />
          </div>

          <%!-- SEO Checks --%>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div
              :for={{label, passed} <- @seo_result.checks}
              class={"flex items-center gap-2 px-3 py-2 rounded-lg text-xs #{if passed, do: "bg-green-50 text-green-700", else: "bg-red-50 text-red-600"}"}
            >
              <span class="material-symbols-outlined text-sm">
                {if passed, do: "check_circle", else: "cancel"}
              </span>
              {label |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()}
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Meta Title</label>
            <input
              type="text"
              name="post[meta_title]"
              value={@form_data[:meta_title]}
              phx-debounce="300"
              maxlength="70"
              placeholder="SEO title (max 70 characters)"
              class="w-full rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
            />
            <p class="text-xs text-on-surface-variant mt-1">
              {String.length(@form_data[:meta_title] || "")}/70 characters
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Meta Description</label>
            <textarea
              name="post[meta_description]"
              rows="2"
              phx-debounce="300"
              maxlength="160"
              placeholder="SEO description (50-160 characters)"
              class="w-full rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors resize-none"
            >{@form_data[:meta_description]}</textarea>
            <p class="text-xs text-on-surface-variant mt-1">
              {String.length(@form_data[:meta_description] || "")}/160 characters
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-on-surface mb-2">OG Image URL</label>
              <input
                type="url"
                name="post[og_image_url]"
                value={@form_data[:og_image_url]}
                phx-debounce="300"
                placeholder="https://..."
                class="w-full rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-on-surface mb-2">Canonical URL</label>
              <input
                type="url"
                name="post[canonical_url]"
                value={@form_data[:canonical_url]}
                phx-debounce="300"
                placeholder="https://..."
                class="w-full rounded-lg border border-outline-variant/30 px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
              />
            </div>
          </div>
        </div>

        <%!-- Submit --%>
        <div class="flex items-center justify-end gap-4">
          <a
            href="/admin/blog"
            class="px-5 py-2.5 rounded-lg text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
          >
            Cancel
          </a>
          <button
            type="submit"
            class="primary-gradient px-6 py-2.5 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.02] active:scale-95"
          >
            {if @editing, do: "Update Post", else: "Create Post"}
          </button>
        </div>
      </form>
    </div>
    """
  end

  def handle_event("validate", %{"post" => post_params}, socket) do
    form_data = merge_form_data(socket.assigns.form_data, post_params)
    selected_cat_ids = MapSet.new(Map.get(post_params, "category_ids", []))
    selected_tag_ids = MapSet.new(Map.get(post_params, "tag_ids", []))

    {:noreply,
     assign(socket,
       form_data: form_data,
       selected_category_ids: selected_cat_ids,
       selected_tag_ids: selected_tag_ids,
       seo_result: SeoScorer.score(form_data),
       form_errors: validate_form(form_data)
     )}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :featured_image, ref)}
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    user = socket.assigns.current_user
    form_data = merge_form_data(socket.assigns.form_data, post_params)
    errors = validate_form(form_data)

    if map_size(errors) > 0 do
      {:noreply,
       socket
       |> assign(form_data: form_data, form_errors: errors)
       |> put_flash(:error, "Please fix the errors below.")}
    else
      featured_image_url = consume_featured_image(socket)

      params =
        %{
          title: form_data[:title],
          slug: form_data[:slug],
          body: form_data[:body],
          excerpt: form_data[:excerpt],
          status: String.to_existing_atom(form_data[:status] || "draft"),
          meta_title: form_data[:meta_title],
          meta_description: form_data[:meta_description],
          og_image_url: form_data[:og_image_url],
          canonical_url: form_data[:canonical_url],
          featured_image_url: featured_image_url || form_data[:featured_image_url]
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()

      category_ids = Map.get(post_params, "category_ids", [])
      tag_ids = Map.get(post_params, "tag_ids", [])

      case save_post(socket, params, user, category_ids, tag_ids) do
        {:ok, _post} ->
          {:noreply,
           socket
           |> put_flash(:info, if(socket.assigns.editing, do: "Post updated.", else: "Post created."))
           |> push_navigate(to: "/admin/blog")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(form_errors: changeset_to_errors(changeset))
           |> put_flash(:error, "Failed to save post.")}
      end
    end
  end

  defp save_post(socket, params, user, category_ids, tag_ids) do
    result =
      if socket.assigns.editing do
        socket.assigns.post
        |> Ash.Changeset.for_update(:update, params, actor: user)
        |> Ash.update()
      else
        params = Map.put(params, :author_id, user.id)

        FounderPad.Content.Post
        |> Ash.Changeset.for_create(:create, params, actor: user)
        |> Ash.create()
      end

    case result do
      {:ok, post} ->
        sync_categories(post, category_ids, user)
        sync_tags(post, tag_ids, user)
        {:ok, post}

      error ->
        error
    end
  end

  defp sync_categories(post, category_ids, user) do
    # Remove existing
    FounderPad.Content.PostCategory
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(post_id == ^post.id)
    |> Ash.read!()
    |> Enum.each(fn pc ->
      pc |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy!()
    end)

    # Add new
    Enum.each(category_ids, fn cat_id ->
      FounderPad.Content.PostCategory
      |> Ash.Changeset.for_create(:create, %{post_id: post.id, category_id: cat_id}, actor: user)
      |> Ash.create!()
    end)
  end

  defp sync_tags(post, tag_ids, user) do
    # Remove existing
    FounderPad.Content.PostTag
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(post_id == ^post.id)
    |> Ash.read!()
    |> Enum.each(fn pt ->
      pt |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy!()
    end)

    # Add new
    Enum.each(tag_ids, fn tag_id ->
      FounderPad.Content.PostTag
      |> Ash.Changeset.for_create(:create, %{post_id: post.id, tag_id: tag_id}, actor: user)
      |> Ash.create!()
    end)
  end

  defp consume_featured_image(socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :featured_image, fn %{path: path}, entry ->
        dest =
          Path.join([
            Application.app_dir(:founder_pad, "priv/static/uploads/blog"),
            "#{Ash.UUID.generate()}_#{entry.client_name}"
          ])

        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)

        {:ok, "/uploads/blog/#{Path.basename(dest)}"}
      end)

    List.first(uploaded_files)
  end

  defp load_categories(user) do
    FounderPad.Content.Category
    |> Ash.Query.for_read(:read, %{}, actor: user)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(actor: user)
  end

  defp load_tags(user) do
    FounderPad.Content.Tag
    |> Ash.Query.for_read(:read, %{}, actor: user)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(actor: user)
  end

  defp default_form_data do
    %{
      title: "",
      slug: "",
      body: "",
      excerpt: "",
      status: "draft",
      meta_title: "",
      meta_description: "",
      og_image_url: "",
      canonical_url: "",
      featured_image_url: nil
    }
  end

  defp post_to_form_data(post) do
    %{
      title: post.title || "",
      slug: post.slug || "",
      body: post.body || "",
      excerpt: post.excerpt || "",
      status: Atom.to_string(post.status),
      meta_title: post.meta_title || "",
      meta_description: post.meta_description || "",
      og_image_url: post.og_image_url || "",
      canonical_url: post.canonical_url || "",
      featured_image_url: post.featured_image_url
    }
  end

  defp merge_form_data(existing, params) do
    %{
      title: Map.get(params, "title", existing[:title]),
      slug: Map.get(params, "slug", existing[:slug]),
      body: Map.get(params, "body", existing[:body]),
      excerpt: Map.get(params, "excerpt", existing[:excerpt]),
      status: Map.get(params, "status", existing[:status]),
      meta_title: Map.get(params, "meta_title", existing[:meta_title]),
      meta_description: Map.get(params, "meta_description", existing[:meta_description]),
      og_image_url: Map.get(params, "og_image_url", existing[:og_image_url]),
      canonical_url: Map.get(params, "canonical_url", existing[:canonical_url]),
      featured_image_url: existing[:featured_image_url]
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

    errors
  end

  defp changeset_to_errors({:error, %Ash.Error.Invalid{} = error}) do
    error.errors
    |> Enum.map(fn e -> {e.field, e.message} end)
    |> Map.new()
  end

  defp changeset_to_errors(_), do: %{}
end
