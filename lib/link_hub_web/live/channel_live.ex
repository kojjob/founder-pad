defmodule LinkHubWeb.ChannelLive do
  @moduledoc "LiveView for real-time channel messaging."
  use LinkHubWeb, :live_view

  require Ash.Query

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user

    workspace =
      case get_user_workspace(user) do
        nil -> nil
        ws -> ws
      end

    socket =
      socket
      |> assign(
        active_nav: :channels,
        page_title: "Messages",
        workspace: workspace,
        channels: [],
        current_channel: nil,
        messages: [],
        compose_body: "",
        thread_parent: nil,
        thread_replies: [],
        typing_users: %{},
        show_new_channel_form: false,
        new_channel_name: "",
        new_channel_visibility: :public,
        search_query: "",
        search_results: []
      )
      |> allow_upload(:file,
        accept: :any,
        max_entries: 5,
        max_file_size: 20_000_000
      )

    socket = mount_workspace(socket, workspace, params, user)

    {:ok, socket}
  end

  defp mount_workspace(socket, nil, _params, _user), do: socket

  defp mount_workspace(socket, workspace, params, user) do
    channels = load_channels(workspace.id)
    socket = assign(socket, channels: channels)
    channel = find_initial_channel(channels, params["id"])

    if channel, do: load_channel(socket, channel, user), else: socket
  end

  defp find_initial_channel([], _id), do: nil
  defp find_initial_channel(channels, nil), do: hd(channels)
  defp find_initial_channel(channels, id), do: Enum.find(channels, &(&1.id == id))

  @impl true
  def handle_params(%{"id" => channel_id}, _uri, socket) do
    user = socket.assigns.current_user

    case Enum.find(socket.assigns.channels, &(&1.id == channel_id)) do
      nil -> {:noreply, socket}
      channel -> {:noreply, load_channel(socket, channel, user)}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # ── Events ──

  @impl true
  def handle_event("send_message", %{"body" => body}, socket) do
    user = socket.assigns.current_user
    channel = socket.assigns.current_channel
    workspace = socket.assigns.workspace
    body = String.trim(body || "")
    uploaded_files = consume_uploaded_files(socket, user, workspace)

    if body == "" and uploaded_files == [] do
      {:noreply, socket}
    else
      message_body =
        if(body == "" and uploaded_files != [],
          do: Enum.map_join(uploaded_files, ", ", & &1.filename),
          else: body
        )

      send_channel_message(socket, channel, user, message_body, uploaded_files)
    end
  end

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :file, ref)}
  end

  def handle_event("update_compose", %{"body" => body}, socket) do
    {:noreply, assign(socket, compose_body: body)}
  end

  def handle_event("send_reply", %{"body" => body}, socket) when body != "" do
    user = socket.assigns.current_user
    channel = socket.assigns.current_channel
    parent = socket.assigns.thread_parent

    case LinkHub.Messaging.Message
         |> Ash.Changeset.for_create(:send, %{
           body: String.trim(body),
           channel_id: channel.id,
           author_id: user.id,
           parent_message_id: parent.id
         })
         |> Ash.create() do
      {:ok, _reply} -> {:noreply, socket}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to send reply")}
    end
  end

  def handle_event("send_reply", _params, socket), do: {:noreply, socket}

  def handle_event("open_thread", %{"message-id" => message_id}, socket) do
    parent =
      LinkHub.Messaging.Message
      |> Ash.get!(message_id)
      |> Ash.load!([:author])

    replies =
      LinkHub.Messaging.Message
      |> Ash.Query.for_read(:list_thread, %{parent_message_id: message_id})
      |> Ash.read!()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(LinkHub.PubSub, "thread:#{message_id}")
    end

    {:noreply, assign(socket, thread_parent: parent, thread_replies: replies)}
  end

  def handle_event("close_thread", _params, socket) do
    if socket.assigns.thread_parent do
      Phoenix.PubSub.unsubscribe(LinkHub.PubSub, "thread:#{socket.assigns.thread_parent.id}")
    end

    {:noreply, assign(socket, thread_parent: nil, thread_replies: [])}
  end

  def handle_event("add_reaction", %{"message-id" => message_id, "emoji" => emoji}, socket) do
    user = socket.assigns.current_user

    LinkHub.Messaging.Reaction
    |> Ash.Changeset.for_create(:add, %{emoji: emoji, message_id: message_id, user_id: user.id})
    |> Ash.create()

    {:noreply, reload_messages(socket)}
  end

  def handle_event("select_channel", %{"id" => channel_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/channels/#{channel_id}")}
  end

  def handle_event("search", %{"query" => ""}, socket) do
    {:noreply, assign(socket, search_query: "", search_results: [])}
  end

  def handle_event("search", %{"query" => query}, socket) do
    channel = socket.assigns.current_channel

    results =
      if channel do
        LinkHub.Messaging.Message
        |> Ash.Query.for_read(:search, %{channel_id: channel.id, query: query})
        |> Ash.read!()
      else
        []
      end

    {:noreply, assign(socket, search_query: query, search_results: results)}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, assign(socket, search_query: "", search_results: [])}
  end

  def handle_event("toggle_new_channel", _params, socket) do
    {:noreply, assign(socket, show_new_channel_form: !socket.assigns.show_new_channel_form)}
  end

  def handle_event("create_channel", %{"name" => name, "visibility" => visibility}, socket) do
    user = socket.assigns.current_user
    workspace = socket.assigns.workspace

    visibility_atom =
      case visibility do
        "public" -> :public
        "private" -> :private
        _ -> :public
      end

    case LinkHub.Messaging.Channel
         |> Ash.Changeset.for_create(:create, %{
           name: name,
           visibility: visibility_atom,
           workspace_id: workspace.id,
           created_by_id: user.id
         })
         |> Ash.create() do
      {:ok, channel} ->
        # Auto-join the creator
        LinkHub.Messaging.ChannelMembership
        |> Ash.Changeset.for_create(:join, %{channel_id: channel.id, user_id: user.id})
        |> Ash.create!()

        channels = load_channels(workspace.id)

        socket =
          socket
          |> assign(channels: channels, show_new_channel_form: false, new_channel_name: "")
          |> load_channel(channel, user)

        {:noreply, push_patch(socket, to: ~p"/channels/#{channel.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create channel")}
    end
  end

  defp send_channel_message(socket, channel, user, body, uploaded_files) do
    case LinkHub.Messaging.Message
         |> Ash.Changeset.for_create(:send, %{
           body: body,
           channel_id: channel.id,
           author_id: user.id
         })
         |> Ash.create() do
      {:ok, message} ->
        attach_files(message.id, channel.id, uploaded_files)
        {:noreply, assign(socket, compose_body: "")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  defp attach_files(_message_id, _channel_id, []), do: :ok

  defp attach_files(message_id, channel_id, uploaded_files) do
    Enum.each(uploaded_files, fn file_attrs ->
      {:ok, stored_file} =
        LinkHub.Media.StoredFile
        |> Ash.Changeset.for_create(:upload, file_attrs)
        |> Ash.create()

      # Link to message context
      LinkHub.Media.FileContext
      |> Ash.Changeset.for_create(:create, %{
        context_type: :message,
        stored_file_id: stored_file.id,
        message_id: message_id,
        channel_id: channel_id
      })
      |> Ash.create!()

      # Enqueue async processing
      %{"file_id" => stored_file.id}
      |> LinkHub.Media.Workers.FileProcessor.new()
      |> Oban.insert()
    end)
  end

  # ── PubSub Handlers ──

  @impl true
  def handle_info({:new_message, message}, socket) do
    if message.parent_message_id do
      # Thread reply
      if socket.assigns.thread_parent &&
           socket.assigns.thread_parent.id == message.parent_message_id do
        message = Ash.load!(message, [:author, :reactions])
        {:noreply, assign(socket, thread_replies: socket.assigns.thread_replies ++ [message])}
      else
        {:noreply, socket}
      end
    else
      message = Ash.load!(message, [:author, :reactions, :reply_count, :attachments])
      {:noreply, assign(socket, messages: socket.assigns.messages ++ [message])}
    end
  end

  def handle_info({:message_edited, updated_message}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn msg ->
        if msg.id == updated_message.id,
          do: Ash.load!(updated_message, [:author, :reactions, :reply_count, :attachments]),
          else: msg
      end)

    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:message_deleted, deleted_message}, socket) do
    messages = Enum.reject(socket.assigns.messages, &(&1.id == deleted_message.id))
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # ── Helpers ──

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

  defp load_channels(workspace_id) do
    LinkHub.Messaging.Channel
    |> Ash.Query.for_read(:list_by_workspace, %{workspace_id: workspace_id})
    |> Ash.read!()
  end

  defp load_channel(socket, channel, user) do
    # Subscribe to channel PubSub topic
    if connected?(socket) do
      # Unsubscribe from previous channel if any
      if socket.assigns.current_channel do
        Phoenix.PubSub.unsubscribe(
          LinkHub.PubSub,
          "channel:#{socket.assigns.current_channel.id}"
        )
      end

      Phoenix.PubSub.subscribe(LinkHub.PubSub, "channel:#{channel.id}")
    end

    # Ensure user is a member
    ensure_channel_membership(channel, user)

    messages =
      LinkHub.Messaging.Message
      |> Ash.Query.for_read(:list_by_channel, %{channel_id: channel.id})
      |> Ash.Query.load([:reply_count, :attachments])
      |> Ash.read!()

    assign(socket,
      current_channel: channel,
      messages: messages,
      page_title: "##{channel.name}",
      thread_parent: nil,
      thread_replies: []
    )
  end

  defp reload_messages(socket) do
    if socket.assigns.current_channel do
      messages =
        LinkHub.Messaging.Message
        |> Ash.Query.for_read(:list_by_channel, %{channel_id: socket.assigns.current_channel.id})
        |> Ash.Query.load([:reply_count, :attachments])
        |> Ash.read!()

      assign(socket, messages: messages)
    else
      socket
    end
  end

  defp ensure_channel_membership(channel, user) do
    case LinkHub.Messaging.ChannelMembership
         |> Ash.Query.filter(channel_id == ^channel.id and user_id == ^user.id)
         |> Ash.read_one() do
      {:ok, nil} ->
        LinkHub.Messaging.ChannelMembership
        |> Ash.Changeset.for_create(:join, %{channel_id: channel.id, user_id: user.id})
        |> Ash.create()

      _ ->
        :ok
    end
  end

  defp consume_uploaded_files(socket, user, workspace) do
    consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
      storage_key = "uploads/#{Ash.UUID.generate()}/#{entry.client_name}"

      # Upload through storage adapter
      {:ok, _key} =
        LinkHub.Media.Storage.upload_file(storage_key, path, content_type: entry.client_type)

      {:ok,
       %{
         filename: entry.client_name,
         content_type: entry.client_type,
         size_bytes: entry.client_size,
         storage_key: storage_key,
         workspace_id: workspace.id,
         uploader_id: user.id
       }}
    end)
  end

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_file_size(_), do: ""

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  defp user_initials(nil), do: "?"

  defp user_initials(user) do
    name =
      case user do
        %{name: name} when is_binary(name) and name != "" -> name
        %{email: email} when is_binary(email) -> email
        _ -> "?"
      end

    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  # ── Template ──

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-[calc(100vh-0px)] overflow-hidden">
      <%!-- Channel Sidebar --%>
      <aside class="w-60 flex-shrink-0 bg-surface-container-lowest border-r border-outline-variant/10 flex flex-col">
        <div class="p-3 border-b border-outline-variant/10">
          <div class="flex items-center justify-between mb-2">
            <h2 class="text-sm font-bold text-on-surface/80 uppercase tracking-wider">Channels</h2>
            <button
              phx-click="toggle_new_channel"
              class="p-1 rounded-md hover:bg-surface-container-high text-on-surface/50 hover:text-on-surface transition-colors"
              aria-label="Create channel"
            >
              <span class="material-symbols-outlined text-lg">add</span>
            </button>
          </div>

          <%= if @show_new_channel_form do %>
            <form id="new-channel-form" phx-submit="create_channel" class="space-y-2">
              <input
                type="text"
                name="name"
                value={@new_channel_name}
                placeholder="channel-name"
                class="w-full px-2 py-1.5 text-sm bg-surface-container border border-outline-variant/20 rounded-md text-on-surface placeholder:text-on-surface/30 focus:border-primary focus:ring-1 focus:ring-primary outline-none"
                autofocus
                phx-debounce="300"
              />
              <select
                name="visibility"
                class="w-full px-2 py-1.5 text-sm bg-surface-container border border-outline-variant/20 rounded-md text-on-surface outline-none"
              >
                <option value="public">Public</option>
                <option value="private">Private</option>
              </select>
              <div class="flex gap-2">
                <button
                  type="submit"
                  class="flex-1 px-2 py-1.5 text-sm bg-primary text-on-primary rounded-md font-medium hover:brightness-110 transition"
                >
                  Create
                </button>
                <button
                  type="button"
                  phx-click="toggle_new_channel"
                  class="px-2 py-1.5 text-sm text-on-surface/50 hover:text-on-surface rounded-md transition"
                >
                  Cancel
                </button>
              </div>
            </form>
          <% end %>
        </div>

        <nav class="flex-1 overflow-y-auto p-2 space-y-0.5">
          <%= for channel <- @channels do %>
            <button
              phx-click="select_channel"
              phx-value-id={channel.id}
              class={[
                "w-full text-left px-3 py-1.5 rounded-md text-sm transition-colors flex items-center gap-2",
                if(@current_channel && @current_channel.id == channel.id,
                  do: "bg-primary/10 text-primary font-semibold",
                  else: "text-on-surface/60 hover:bg-surface-container-high hover:text-on-surface"
                )
              ]}
            >
              <span class="material-symbols-outlined text-base">
                {if channel.visibility == :private, do: "lock", else: "tag"}
              </span>
              <span class="truncate">{channel.name}</span>
            </button>
          <% end %>

          <%= if @channels == [] do %>
            <p class="px-3 py-4 text-sm text-on-surface/40 text-center">
              No channels yet. Create one to start chatting.
            </p>
          <% end %>
        </nav>
      </aside>

      <%!-- Main Chat Area --%>
      <div class="flex-1 flex flex-col min-w-0">
        <%= if @current_channel do %>
          <%!-- Channel Header --%>
          <header class="h-14 flex items-center justify-between px-4 border-b border-outline-variant/10 flex-shrink-0">
            <div class="flex items-center gap-2">
              <span class="material-symbols-outlined text-on-surface/40 text-lg">
                {if @current_channel.visibility == :private, do: "lock", else: "tag"}
              </span>
              <h1 class="text-base font-bold text-on-surface">{@current_channel.name}</h1>
              <%= if @current_channel.description do %>
                <span class="ml-2 text-sm text-on-surface/40 truncate max-w-xs">
                  {@current_channel.description}
                </span>
              <% end %>
            </div>
            <form phx-change="search" phx-submit="search" class="relative">
              <span class="material-symbols-outlined absolute left-2.5 top-1/2 -translate-y-1/2 text-on-surface/30 text-sm">
                search
              </span>
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search messages..."
                class="pl-8 pr-3 py-1.5 w-48 bg-surface-container border border-outline-variant/20 rounded-lg text-sm text-on-surface placeholder:text-on-surface/30 focus:border-primary focus:ring-1 focus:ring-primary outline-none"
                autocomplete="off"
                phx-debounce="300"
              />
              <%= if @search_query != "" do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="absolute right-2 top-1/2 -translate-y-1/2 text-on-surface/30 hover:text-on-surface"
                >
                  <span class="material-symbols-outlined text-sm">close</span>
                </button>
              <% end %>
            </form>
          </header>

          <%!-- Search Results Overlay --%>
          <%= if @search_results != [] do %>
            <div class="border-b border-outline-variant/10 bg-surface-container-lowest px-4 py-2 max-h-48 overflow-y-auto">
              <p class="text-xs text-on-surface/40 mb-2">
                {length(@search_results)} results for "{@search_query}"
              </p>
              <%= for result <- @search_results do %>
                <div class="flex gap-2 py-1.5 text-sm">
                  <span class="font-medium text-on-surface/70">
                    {result.author.name || result.author.email}:
                  </span>
                  <span class="text-on-surface/50 truncate">{result.body}</span>
                  <span class="text-xs text-on-surface/30 flex-shrink-0">
                    {format_time(result.inserted_at)}
                  </span>
                </div>
              <% end %>
            </div>
          <% end %>

          <%!-- Message List --%>
          <div
            id="message-list"
            class="flex-1 overflow-y-auto px-4 py-3 space-y-1"
            phx-hook="ScrollBottom"
          >
            <%= for message <- @messages do %>
              <div
                id={"msg-#{message.id}"}
                class="group flex gap-3 py-2 px-2 rounded-lg hover:bg-surface-container-high/50 transition-colors"
              >
                <%!-- Avatar --%>
                <div class="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0 text-xs font-bold text-primary">
                  {user_initials(message.author)}
                </div>

                <%!-- Content --%>
                <div class="flex-1 min-w-0">
                  <div class="flex items-baseline gap-2">
                    <span class="font-semibold text-sm text-on-surface">
                      {message.author.name || message.author.email}
                    </span>
                    <span class="text-xs text-on-surface/30">{format_time(message.inserted_at)}</span>
                    <%= if message.edited_at do %>
                      <span class="text-xs text-on-surface/20">(edited)</span>
                    <% end %>
                  </div>
                  <p class="text-sm text-on-surface/80 whitespace-pre-wrap break-words">
                    {message.body}
                  </p>

                  <%!-- Reactions --%>
                  <%= if message.reactions != [] do %>
                    <div class="flex flex-wrap gap-1 mt-1">
                      <%= for {emoji, reactions} <- Enum.group_by(message.reactions, & &1.emoji) do %>
                        <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-surface-container text-xs text-on-surface/60 border border-outline-variant/10">
                          {emoji} <span class="font-medium">{length(reactions)}</span>
                        </span>
                      <% end %>
                    </div>
                  <% end %>

                  <%!-- File attachments --%>
                  <%= if message.attachments != [] do %>
                    <div class="flex flex-wrap gap-2 mt-1.5">
                      <%= for attachment <- message.attachments do %>
                        <a
                          href={"/uploads/#{attachment.storage_path}"}
                          target="_blank"
                          class="flex items-center gap-2 px-3 py-1.5 bg-surface-container hover:bg-surface-container-high rounded-lg text-xs border border-outline-variant/10 transition-colors group"
                        >
                          <span class="material-symbols-outlined text-sm text-on-surface/40 group-hover:text-primary">
                            {if String.starts_with?(attachment.content_type || "", "image/"),
                              do: "image",
                              else: "description"}
                          </span>
                          <span class="text-on-surface/70 truncate max-w-[150px]">
                            {attachment.filename}
                          </span>
                          <span class="text-on-surface/30">
                            {format_file_size(attachment.size_bytes)}
                          </span>
                        </a>
                      <% end %>
                    </div>
                  <% end %>

                  <%!-- Thread indicator --%>
                  <%= if message.reply_count && message.reply_count > 0 do %>
                    <button
                      phx-click="open_thread"
                      phx-value-message-id={message.id}
                      class="mt-1 text-xs text-primary hover:underline font-medium"
                    >
                      {message.reply_count} {if message.reply_count == 1, do: "reply", else: "replies"}
                    </button>
                  <% end %>
                </div>

                <%!-- Hover actions --%>
                <div class="hidden group-hover:flex items-center gap-1 flex-shrink-0">
                  <button
                    phx-click="add_reaction"
                    phx-value-message-id={message.id}
                    phx-value-emoji="thumbsup"
                    class="p-1 rounded hover:bg-surface-container text-on-surface/30 hover:text-on-surface/60 transition-colors"
                    title="React"
                  >
                    <span class="material-symbols-outlined text-base">add_reaction</span>
                  </button>
                  <button
                    phx-click="open_thread"
                    phx-value-message-id={message.id}
                    class="p-1 rounded hover:bg-surface-container text-on-surface/30 hover:text-on-surface/60 transition-colors"
                    title="Reply in thread"
                  >
                    <span class="material-symbols-outlined text-base">comment</span>
                  </button>
                </div>
              </div>
            <% end %>

            <%= if @messages == [] do %>
              <div class="flex flex-col items-center justify-center h-full text-on-surface/30">
                <span class="material-symbols-outlined text-5xl mb-3">chat_bubble_outline</span>
                <p class="text-sm">No messages yet. Start the conversation!</p>
              </div>
            <% end %>
          </div>

          <%!-- Compose Box --%>
          <div
            class="p-3 border-t border-outline-variant/10 flex-shrink-0"
            phx-drop-target={@uploads.file.ref}
          >
            <%!-- Upload previews --%>
            <%= if @uploads.file.entries != [] do %>
              <div class="flex flex-wrap gap-2 mb-2">
                <%= for entry <- @uploads.file.entries do %>
                  <div class="flex items-center gap-2 px-3 py-1.5 bg-surface-container rounded-lg text-xs text-on-surface/70 border border-outline-variant/10">
                    <span class="material-symbols-outlined text-sm">attach_file</span>
                    <span class="truncate max-w-[120px]">{entry.client_name}</span>
                    <span class="text-on-surface/40">{format_file_size(entry.client_size)}</span>
                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                      class="text-on-surface/30 hover:text-error transition-colors"
                    >
                      <span class="material-symbols-outlined text-sm">close</span>
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>

            <form
              id="compose-form"
              phx-submit="send_message"
              phx-change="validate_upload"
              class="flex gap-2"
            >
              <label class="p-2.5 rounded-xl border border-outline-variant/20 bg-surface-container hover:bg-surface-container-high cursor-pointer transition-colors flex items-center">
                <.live_file_input upload={@uploads.file} class="hidden" />
                <span class="material-symbols-outlined text-base text-on-surface/40">
                  attach_file
                </span>
              </label>
              <input
                type="text"
                name="body"
                value={@compose_body}
                placeholder={"Message ##{@current_channel.name}"}
                class="flex-1 px-4 py-2.5 bg-surface-container border border-outline-variant/20 rounded-xl text-sm text-on-surface placeholder:text-on-surface/30 focus:border-primary focus:ring-1 focus:ring-primary outline-none"
                autocomplete="off"
                phx-debounce="100"
              />
              <button
                type="submit"
                class="px-4 py-2.5 bg-primary text-on-primary rounded-xl text-sm font-semibold hover:brightness-110 transition flex items-center gap-1.5 disabled:opacity-40"
                disabled={@compose_body == "" and @uploads.file.entries == []}
              >
                <span class="material-symbols-outlined text-base">send</span> Send
              </button>
            </form>
          </div>
        <% else %>
          <%!-- No channel selected --%>
          <div class="flex-1 flex flex-col items-center justify-center text-on-surface/30">
            <span class="material-symbols-outlined text-6xl mb-4">forum</span>
            <p class="text-lg font-medium">Select a channel to start messaging</p>
            <p class="text-sm mt-1">Or create a new one from the sidebar</p>
          </div>
        <% end %>
      </div>

      <%!-- Thread Panel --%>
      <%= if @thread_parent do %>
        <aside class="w-80 flex-shrink-0 border-l border-outline-variant/10 flex flex-col bg-surface-container-lowest">
          <header class="h-14 flex items-center justify-between px-4 border-b border-outline-variant/10 flex-shrink-0">
            <h2 class="text-sm font-bold text-on-surface">Thread</h2>
            <button
              phx-click="close_thread"
              class="p-1 rounded-md hover:bg-surface-container-high text-on-surface/40 hover:text-on-surface transition-colors"
            >
              <span class="material-symbols-outlined text-lg">close</span>
            </button>
          </header>

          <%!-- Parent message --%>
          <div class="px-4 py-3 border-b border-outline-variant/10">
            <div class="flex gap-3">
              <div class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0 text-xs font-bold text-primary">
                {user_initials(@thread_parent.author)}
              </div>
              <div>
                <div class="flex items-baseline gap-2">
                  <span class="font-semibold text-sm text-on-surface">
                    {@thread_parent.author.name || @thread_parent.author.email}
                  </span>
                  <span class="text-xs text-on-surface/30">
                    {format_time(@thread_parent.inserted_at)}
                  </span>
                </div>
                <p class="text-sm text-on-surface/80 whitespace-pre-wrap">{@thread_parent.body}</p>
              </div>
            </div>
          </div>

          <%!-- Replies --%>
          <div class="flex-1 overflow-y-auto px-4 py-2 space-y-1">
            <%= for reply <- @thread_replies do %>
              <div class="flex gap-3 py-2">
                <div class="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0 text-xs font-bold text-primary">
                  {user_initials(reply.author)}
                </div>
                <div class="min-w-0">
                  <div class="flex items-baseline gap-2">
                    <span class="font-semibold text-xs text-on-surface">
                      {reply.author.name || reply.author.email}
                    </span>
                    <span class="text-xs text-on-surface/30">{format_time(reply.inserted_at)}</span>
                  </div>
                  <p class="text-sm text-on-surface/80 whitespace-pre-wrap">{reply.body}</p>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Thread compose --%>
          <div class="p-3 border-t border-outline-variant/10 flex-shrink-0">
            <form id="reply-form" phx-submit="send_reply" class="flex gap-2">
              <input
                type="text"
                name="body"
                placeholder="Reply..."
                class="flex-1 px-3 py-2 bg-surface-container border border-outline-variant/20 rounded-lg text-sm text-on-surface placeholder:text-on-surface/30 focus:border-primary focus:ring-1 focus:ring-primary outline-none"
                autocomplete="off"
              />
              <button
                type="submit"
                class="p-2 bg-primary text-on-primary rounded-lg hover:brightness-110 transition"
              >
                <span class="material-symbols-outlined text-base">send</span>
              </button>
            </form>
          </div>
        </aside>
      <% end %>
    </div>
    """
  end
end
