defmodule LinkHubWeb.FileBrowserLive do
  @moduledoc "LiveView for browsing workspace files."
  use LinkHubWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    workspace = get_user_workspace(socket.assigns.current_user)
    {:ok, assign(socket, page_title: "Files", search_query: "", files: [], workspace: workspace)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    if connected?(socket) and socket.assigns.workspace do
      {:noreply, load_files(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, search_query: query)
    {:noreply, load_files(socket)}
  end

  defp get_user_workspace(nil), do: nil

  defp get_user_workspace(user) do
    case LinkHub.Accounts.Membership
         |> Ash.Query.filter(user_id == ^user.id)
         |> Ash.Query.limit(1)
         |> Ash.Query.load(:workspace)
         |> Ash.read!() do
      [membership | _] -> membership.workspace
      [] -> nil
    end
  end

  defp load_files(socket) do
    workspace = socket.assigns.workspace
    query = socket.assigns.search_query

    files =
      if query != "" do
        LinkHub.Media.StoredFile
        |> Ash.Query.for_read(:search, %{workspace_id: workspace.id, query: query})
        |> Ash.read!()
      else
        LinkHub.Media.StoredFile
        |> Ash.Query.for_read(:list_ready_by_workspace, %{workspace_id: workspace.id})
        |> Ash.read!()
      end

    assign(socket, files: files)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <section class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div class="space-y-1">
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">Files</h1>
          <p class="text-on-surface-variant font-medium">
            Browse and search workspace files
          </p>
        </div>
      </section>

      <div>
        <form id="file-search-form" phx-change="search" phx-submit="search">
          <input
            type="text"
            name="query"
            value={@search_query}
            placeholder="Search files..."
            phx-debounce="300"
            class="w-full max-w-md rounded-lg border border-outline-variant bg-surface-container px-4 py-2 text-sm text-on-surface placeholder-on-surface-variant focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
          />
        </form>
      </div>

      <div class="grid gap-4">
        <%= if @files == [] do %>
          <div class="bg-surface-container-lowest rounded-lg p-12 text-center">
            <span class="material-symbols-outlined text-4xl mb-2 block opacity-30">
              folder_open
            </span>
            <p class="text-on-surface-variant text-sm">No files found</p>
            <p class="text-xs mt-1 opacity-60">
              Upload files in a channel to see them here
            </p>
          </div>
        <% else %>
          <div class="bg-surface-container-lowest rounded-lg overflow-hidden">
            <div class="grid grid-cols-12 gap-4 px-6 py-4 bg-surface-container/30 text-xs font-mono uppercase tracking-widest text-on-surface-variant">
              <div class="col-span-5">Name</div>
              <div class="col-span-3">Type</div>
              <div class="col-span-2">Size</div>
              <div class="col-span-2">Uploaded</div>
            </div>
            <div
              :for={file <- @files}
              class="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-surface-container-high/50 transition-colors"
            >
              <div class="col-span-5 flex items-center gap-3">
                <div class="w-8 h-8 rounded bg-surface-container-highest flex items-center justify-center">
                  <span class="material-symbols-outlined text-lg text-primary">
                    {file_icon(file.content_type)}
                  </span>
                </div>
                <span class="text-sm font-medium text-on-surface truncate">
                  {file.filename}
                </span>
              </div>
              <div class="col-span-3 text-sm text-on-surface-variant font-mono">
                {file.content_type}
              </div>
              <div class="col-span-2 text-sm text-on-surface-variant font-mono">
                {format_bytes(file.size_bytes)}
              </div>
              <div class="col-span-2 text-sm text-on-surface-variant font-mono">
                {Calendar.strftime(file.inserted_at, "%b %d, %Y")}
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp file_icon(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> "image"
      String.starts_with?(content_type, "video/") -> "movie"
      String.starts_with?(content_type, "audio/") -> "audio_file"
      content_type == "application/pdf" -> "picture_as_pdf"
      true -> "description"
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
