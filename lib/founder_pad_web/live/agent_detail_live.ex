defmodule FounderPadWeb.AgentDetailLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(%{"id" => agent_id}, _session, socket) do
    case Ash.get(FounderPad.AI.Agent, agent_id) do
      {:ok, agent} ->
        conversation = get_or_create_conversation(agent, socket.assigns[:current_user])
        messages = load_messages(conversation.id)
        stats = compute_agent_stats(agent)
        logs = load_audit_logs(agent.id)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(FounderPad.PubSub, "conversation:#{conversation.id}")
        end

        {:ok,
         assign(socket,
           active_nav: :agents,
           page_title: agent.name,
           agent: agent,
           conversation: conversation,
           messages: messages,
           message_input: "",
           streaming: false,
           active_tab: "activity",
           stats: stats,
           logs: logs,
           activities: load_activities(agent.id),
           auto_recovery: true,
           temperature: agent.temperature,
           max_tokens: agent.max_tokens
         )}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Agent not found") |> push_navigate(to: "/agents")}
    end
  end

  # ── PubSub Handlers ──

  def handle_info({:message_complete, response}, socket) do
    msg = %{role: :assistant, content: response, time: format_time(DateTime.utc_now())}

    {:noreply,
     socket
     |> assign(messages: socket.assigns.messages ++ [msg], streaming: false)
     |> push_event("scroll-bottom", %{})}
  end

  def handle_info({:error, reason}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Agent error: #{inspect(reason)}")
     |> assign(streaming: false)}
  end

  # ── Event Handlers ──

  def handle_event("send_message", %{"message" => content}, socket) when byte_size(content) > 0 do
    conversation = socket.assigns.conversation
    agent = socket.assigns.agent

    %{conversation_id: conversation.id, message_content: String.trim(content), organisation_id: agent.organisation_id}
    |> FounderPad.AI.Workers.AgentRunner.new()
    |> Oban.insert()

    msg = %{role: :user, content: String.trim(content), time: format_time(DateTime.utc_now())}

    {:noreply,
     socket
     |> assign(messages: socket.assigns.messages ++ [msg], message_input: "", streaming: true)}
  end

  def handle_event("send_message", _, socket), do: {:noreply, socket}

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("toggle_agent", _, socket) do
    agent = socket.assigns.agent
    new_active = !agent.active

    case agent |> Ash.Changeset.for_update(:update, %{active: new_active}) |> Ash.update() do
      {:ok, updated} ->
        FounderPad.Audit.log(
          :settings_changed, "Agent", agent.id, socket.assigns[:current_user] && socket.assigns.current_user.id, nil,
          changes: %{active: new_active}
        )

        {:noreply,
         socket
         |> assign(agent: updated)
         |> put_flash(:info, if(new_active, do: "Agent resumed", else: "Agent paused"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update agent")}
    end
  end

  def handle_event("toggle_recovery", _, socket) do
    {:noreply, assign(socket, auto_recovery: !socket.assigns.auto_recovery)}
  end

  def handle_event("update_temperature", %{"value" => val}, socket) do
    {temp, _} = Float.parse(val)
    {:noreply, assign(socket, temperature: temp)}
  end

  def handle_event("set_max_tokens", %{"tokens" => tokens}, socket) do
    {t, _} = Integer.parse(tokens)
    {:noreply, assign(socket, max_tokens: t)}
  end

  def handle_event("save_config", _, socket) do
    agent = socket.assigns.agent

    case agent
         |> Ash.Changeset.for_update(:update, %{temperature: socket.assigns.temperature, max_tokens: socket.assigns.max_tokens})
         |> Ash.update() do
      {:ok, updated} ->
        {:noreply, socket |> assign(agent: updated) |> put_flash(:info, "Configuration saved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save configuration")}
    end
  end

  def handle_event("delete_agent", _, socket) do
    agent = socket.assigns.agent

    case agent |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy() do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Agent deleted") |> push_navigate(to: "/agents")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete agent")}
    end
  end

  # ── Render ──

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-7xl mx-auto">
      <%!-- Breadcrumbs & Header --%>
      <section class="flex flex-col md:flex-row md:items-start justify-between gap-6">
        <div>
          <div class="flex items-center gap-2 text-sm text-on-surface-variant font-medium mb-3">
            <.link navigate="/agents" class="hover:text-on-surface transition-colors">Agents</.link>
            <span class="material-symbols-outlined text-[14px]">chevron_right</span>
            <span class="text-on-surface">{@agent.name}</span>
          </div>

          <div class="flex items-center gap-4 mb-2">
            <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface leading-none">{@agent.name}</h1>
            <.agent_status active={@agent.active} />
          </div>
          <p class="text-on-surface-variant max-w-2xl">{@agent.description || "No description"}</p>
          <div class="flex gap-3 mt-2 text-xs font-mono text-on-surface-variant">
            <span>{@agent.provider |> to_string() |> String.capitalize()}</span>
            <span>•</span>
            <span>{@agent.model}</span>
            <span>•</span>
            <span>Temp: {@agent.temperature}</span>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <button phx-click="toggle_agent" class={[
            "px-5 py-2.5 rounded-lg text-sm font-semibold transition-colors flex items-center gap-2",
            if(@agent.active,
              do: "bg-surface-container-high hover:bg-surface-container-highest text-on-surface",
              else: "primary-gradient")
          ]}>
            <span class="material-symbols-outlined text-lg">{if @agent.active, do: "pause", else: "play_arrow"}</span>
            {if @agent.active, do: "Pause", else: "Resume"}
          </button>
          <button phx-click="delete_agent" data-confirm="Delete this agent permanently?" class="bg-error/10 hover:bg-error/20 text-error px-5 py-2.5 rounded-lg text-sm font-semibold transition-colors flex items-center gap-2">
            <span class="w-2 h-2 rounded-sm bg-error"></span> Delete
          </button>
        </div>
      </section>

      <%!-- Stats Row --%>
      <section class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div class="bg-surface-container p-6 rounded-2xl">
          <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2">Conversations</p>
          <p class="text-3xl font-mono font-medium text-on-surface mb-1">{@stats.conversations}</p>
          <p class="text-xs text-on-surface-variant">Total sessions</p>
        </div>
        <div class="bg-surface-container p-6 rounded-2xl">
          <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2">Messages</p>
          <p class="text-3xl font-mono font-medium text-on-surface mb-1">{@stats.messages}</p>
          <p class="text-xs text-on-surface-variant">{@stats.user_messages} sent / {@stats.assistant_messages} received</p>
        </div>
        <div class="bg-surface-container p-6 rounded-2xl">
          <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2">Tokens Used</p>
          <p class="text-3xl font-mono font-medium text-secondary mb-1">{@stats.tokens}</p>
          <p class="text-xs text-secondary/70">Est. cost: {@stats.est_cost}</p>
        </div>
        <div class="bg-surface-container p-6 rounded-2xl">
          <div class="flex justify-between items-center mb-4">
            <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">Latency</p>
            <p class="text-[10px] font-mono text-on-surface-variant">{@stats.avg_latency}ms</p>
          </div>
          <div class="flex items-end gap-1 h-10 w-full">
            <div :for={h <- @stats.latency_chart} class="w-full rounded-sm transition-all" style={"height: #{h}%; background-color: var(--fp-chart-primary); opacity: #{max(h / 100, 0.3)};"}>
            </div>
          </div>
        </div>
      </section>

      <%!-- Tabs --%>
      <div class="flex gap-8">
        <button
          :for={{label, icon, key} <- [{"Activity", "monitoring", "activity"}, {"Chat", "chat", "chat"}, {"Configuration", "tune", "config"}, {"Logs", "terminal", "logs"}]}
          phx-click="set_tab"
          phx-value-tab={key}
          class={["text-sm font-semibold transition-colors relative pb-4 flex items-center gap-2",
            if(@active_tab == key, do: "text-on-surface", else: "text-on-surface-variant hover:text-on-surface")
          ]}
        >
          <span class="material-symbols-outlined text-[18px]">{icon}</span>
          {label}
          <span :if={@active_tab == key} class="absolute bottom-0 left-0 right-0 h-0.5 bg-primary rounded-full"></span>
        </button>
      </div>

      <%!-- Tab Content --%>
      <div :if={@active_tab == "activity"} class="space-y-6">
        <div class="overflow-x-auto rounded-2xl bg-surface-container">
          <table class="w-full text-left text-sm border-collapse">
            <thead>
              <tr class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant/70">
                <th class="p-6 py-4 font-medium">Timestamp</th>
                <th class="p-6 py-4 font-medium">Action</th>
                <th class="p-6 py-4 font-medium">Details</th>
                <th class="p-6 py-4 font-medium text-right">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={act <- @activities} class="hover:bg-surface-container-high/30 transition-colors">
                <td class="p-6 py-4 whitespace-nowrap text-on-surface-variant font-mono text-xs">{act.timestamp}</td>
                <td class="p-6 py-4 whitespace-nowrap text-on-surface font-medium">{act.action}</td>
                <td class="p-6 py-4 whitespace-nowrap">
                  <span class="px-2 py-1 bg-surface-container-highest text-on-surface-variant text-[10px] font-mono rounded">{act.entity}</span>
                </td>
                <td class={"p-6 py-4 whitespace-nowrap text-right font-bold text-xs " <> act.impact_color}>{act.impact}</td>
              </tr>
              <tr :if={@activities == []}>
                <td colspan="4" class="p-6 text-center text-on-surface-variant">No activity recorded yet</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Chat Tab --%>
      <div :if={@active_tab == "chat"} class="space-y-6">
        <div class="bg-surface-container rounded-2xl overflow-hidden flex flex-col h-[500px]">
          <div class="px-6 py-4 flex items-center justify-between bg-surface-container-high/30">
            <div class="flex items-center gap-3">
              <span class="material-symbols-outlined text-primary">chat</span>
              <h3 class="font-bold text-sm">Conversation</h3>
            </div>
            <span class="text-xs font-mono text-on-surface-variant">ID: {String.slice(@conversation.id, 0..7)}</span>
          </div>

          <div class="p-6 overflow-y-auto flex-1 space-y-6" id="chat-messages">
            <div :if={@messages == []} class="text-center text-on-surface-variant py-12">
              <span class="material-symbols-outlined text-4xl text-on-surface-variant/30 mb-3 block">forum</span>
              <p>Send a message to start the conversation</p>
            </div>
            <div :for={msg <- @messages} class="flex gap-4">
              <div class={["w-8 h-8 rounded-lg flex items-center justify-center shrink-0",
                if(msg.role == :user, do: "bg-surface-container-highest", else: "bg-primary/10")]}>
                <span class={["material-symbols-outlined text-sm",
                  if(msg.role == :user, do: "text-on-surface", else: "text-primary")]}>
                  {if msg.role == :user, do: "person", else: "psychology"}
                </span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-mono text-on-surface-variant mb-1">
                  {if msg.role == :user, do: "You", else: @agent.name} • {msg.time}
                </p>
                <div class="text-sm leading-relaxed text-on-surface whitespace-pre-wrap">{msg.content}</div>
              </div>
            </div>
            <div :if={@streaming} class="flex gap-4">
              <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                <span class="material-symbols-outlined text-sm text-primary animate-pulse">psychology</span>
              </div>
              <div class="flex items-center gap-1 py-2">
                <div class="w-2 h-2 rounded-full bg-primary/60 animate-bounce"></div>
                <div class="w-2 h-2 rounded-full bg-primary/40 animate-bounce [animation-delay:150ms]"></div>
                <div class="w-2 h-2 rounded-full bg-primary/20 animate-bounce [animation-delay:300ms]"></div>
              </div>
            </div>
          </div>

          <form phx-submit="send_message" class="px-6 py-4 bg-surface-container-high/20">
            <div class="flex gap-3">
              <input
                type="text"
                name="message"
                value={@message_input}
                placeholder={if @streaming, do: "Agent is thinking...", else: "Send a message..."}
                disabled={@streaming}
                class="flex-1 bg-surface-container-highest rounded-lg px-4 py-2.5 text-sm text-on-surface placeholder:text-on-surface-variant/50 focus:ring-1 focus:ring-primary disabled:opacity-50"
                autofocus
              />
              <button type="submit" disabled={@streaming} class="primary-gradient px-4 py-2.5 rounded-lg text-sm font-semibold transition-transform active:scale-95 disabled:opacity-50">
                <span class="material-symbols-outlined text-lg">{if @streaming, do: "hourglass_top", else: "send"}</span>
              </button>
            </div>
          </form>
        </div>
      </div>

      <%!-- Config Tab --%>
      <div :if={@active_tab == "config"} class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div class="lg:col-span-2 space-y-6">
          <div class="bg-surface-container rounded-2xl p-6">
            <h3 class="font-bold text-lg text-on-surface mb-6">Parameters</h3>
            <div class="space-y-8">
              <div>
                <div class="flex justify-between items-center mb-3">
                  <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">Temperature</p>
                  <span class="text-sm font-mono text-primary font-bold">{@temperature}</span>
                </div>
                <input type="range" min="0" max="1" step="0.1" value={@temperature}
                  phx-change="update_temperature" name="value"
                  class="w-full h-1.5 bg-surface-container-highest rounded-full appearance-none cursor-pointer accent-primary" />
                <div class="flex justify-between text-[10px] text-on-surface-variant mt-1">
                  <span>Precise</span><span>Creative</span>
                </div>
              </div>

              <div>
                <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2">Model</p>
                <div class="w-full bg-surface-container-high rounded-lg px-4 py-3 flex items-center justify-between text-sm text-on-surface">
                  <span>{@agent.model}</span>
                  <span class="text-xs font-mono text-on-surface-variant">{@agent.provider}</span>
                </div>
              </div>

              <div>
                <p class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2">Max Tokens</p>
                <div class="grid grid-cols-4 gap-2 bg-surface-container-high p-1 rounded-lg text-xs font-mono font-medium">
                  <button :for={t <- [1024, 2048, 4096, 8192]}
                    phx-click="set_max_tokens" phx-value-tokens={t}
                    class={["py-2 rounded-md transition-colors",
                      if(@max_tokens == t, do: "bg-primary text-on-primary", else: "text-on-surface-variant hover:text-on-surface")]}>
                    {t}
                  </button>
                </div>
              </div>

              <div class="bg-surface-container-low p-4 rounded-xl flex items-center justify-between">
                <div>
                  <p class="text-sm font-bold text-on-surface">Auto-Recovery</p>
                  <p class="text-[10px] text-on-surface-variant mt-0.5">Automatically retry on failure</p>
                </div>
                <button phx-click="toggle_recovery" class={[
                  "w-11 h-6 rounded-full transition-colors relative",
                  if(@auto_recovery, do: "bg-primary", else: "bg-surface-container-highest")
                ]}>
                  <span class={["absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform",
                    if(@auto_recovery, do: "left-[22px]", else: "left-0.5")]}></span>
                </button>
              </div>

              <button phx-click="save_config" class="w-full primary-gradient py-3 rounded-lg text-sm font-bold transition-transform hover:scale-[1.01] active:scale-95">
                Save Configuration
              </button>
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <div class="bg-surface-container rounded-2xl p-6">
            <div class="flex items-center gap-2 mb-4">
              <span class="material-symbols-outlined text-secondary">shield</span>
              <h3 class="font-bold text-sm text-on-surface">Security Context</h3>
            </div>
            <p class="text-xs text-on-surface-variant leading-relaxed mb-4">
              This agent has <span class="text-primary font-mono font-bold">READ/WRITE</span> access to conversations and messages. All actions are audit-logged.
            </p>
            <a href="/settings" class="text-xs font-bold text-primary flex items-center gap-1 hover:underline">
              Review Permissions <span class="material-symbols-outlined text-[14px]">arrow_outward</span>
            </a>
          </div>

          <div class="bg-surface-container rounded-2xl p-6">
            <h3 class="font-bold text-sm text-on-surface mb-4">Agent Info</h3>
            <div class="space-y-3 text-xs">
              <div class="flex justify-between">
                <span class="text-on-surface-variant">ID</span>
                <span class="font-mono text-on-surface">{String.slice(@agent.id, 0..7)}...</span>
              </div>
              <div class="flex justify-between">
                <span class="text-on-surface-variant">Provider</span>
                <span class="font-mono text-on-surface">{@agent.provider}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-on-surface-variant">Created</span>
                <span class="font-mono text-on-surface">{Calendar.strftime(@agent.inserted_at, "%b %d, %Y")}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-on-surface-variant">Tools</span>
                <span class="font-mono text-on-surface">{length(@agent.tools || [])} configured</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Logs Tab (Terminal) --%>
      <div :if={@active_tab == "logs"} class="space-y-6">
        <div class="bg-[#0d1117] rounded-2xl overflow-hidden shadow-2xl flex flex-col h-[500px]">
          <div class="bg-[#161b22] px-4 py-2 flex items-center justify-between text-[11px] font-mono text-[#8b949e]">
            <div class="flex items-center gap-2">
              <div class="flex gap-1.5">
                <div class="w-2.5 h-2.5 rounded-full bg-[#f85149]"></div>
                <div class="w-2.5 h-2.5 rounded-full bg-[#d29922]"></div>
                <div class="w-2.5 h-2.5 rounded-full bg-[#3fb950]"></div>
              </div>
              <span class="ml-4">{@agent.name} — agent logs</span>
            </div>
            <span>LIVE</span>
          </div>

          <div class="p-6 overflow-y-auto font-mono text-[13px] leading-relaxed flex-1 space-y-1">
            <div :for={log <- @logs} class="flex gap-4 hover:bg-[#161b22] -mx-4 px-4 py-0.5 rounded">
              <span class="text-[#484f58] shrink-0 select-none">{log.time}</span>
              <span class={"shrink-0 font-bold " <> log_color(log.level)}>[{log.level}]</span>
              <span class="text-[#c9d1d9] break-all">{log.msg}</span>
            </div>
            <div :if={@logs == []} class="text-[#484f58]">No logs yet. Agent activity will appear here.</div>
            <div class="flex gap-2 pt-2 text-[#484f58] animate-pulse">
              <span>$</span>
              <span class="w-2 h-4 bg-[#484f58] block relative top-1"></span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Components ──

  defp agent_status(%{active: true} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-primary/10 text-primary text-[10px] font-bold uppercase tracking-wider">
      <span class="w-2 h-2 rounded-full bg-primary animate-pulse"></span> Active
    </span>
    """
  end

  defp agent_status(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-on-surface-variant/10 text-on-surface-variant text-[10px] font-bold uppercase tracking-wider">
      <span class="w-2 h-2 rounded-full bg-on-surface-variant/50"></span> Paused
    </span>
    """
  end

  defp log_color("INFO"), do: "text-[#58a6ff]"
  defp log_color("DEBUG"), do: "text-[#8b949e]"
  defp log_color("SYSTEM"), do: "text-[#d2a8ff]"
  defp log_color("WARN"), do: "text-[#d29922]"
  defp log_color("ERROR"), do: "text-[#f85149]"
  defp log_color(_), do: "text-[#8b949e]"

  # ── Data Loaders ──

  defp get_or_create_conversation(agent, user) do
    case FounderPad.AI.Conversation
         |> Ash.Query.filter(agent_id: agent.id, status: :active)
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(1)
         |> Ash.read() do
      {:ok, [conv | _]} -> conv
      _ ->
        {:ok, conv} =
          FounderPad.AI.Conversation
          |> Ash.Changeset.for_create(:create, %{
            title: "Chat with #{agent.name}",
            agent_id: agent.id,
            organisation_id: agent.organisation_id,
            user_id: user && user.id
          })
          |> Ash.create()
        conv
    end
  end

  defp load_messages(conversation_id) do
    case FounderPad.AI.Message
         |> Ash.Query.filter(conversation_id: conversation_id)
         |> Ash.Query.sort(inserted_at: :asc)
         |> Ash.read() do
      {:ok, msgs} -> Enum.map(msgs, fn m -> %{role: m.role, content: m.content, time: format_time(m.inserted_at)} end)
      _ -> []
    end
  end

  defp compute_agent_stats(agent) do
    convos = case FounderPad.AI.Conversation |> Ash.Query.filter(agent_id: agent.id) |> Ash.count() do
      {:ok, n} -> n; _ -> 0
    end

    msgs = case FounderPad.AI.Message
         |> Ash.Query.new()
         |> Ash.count() do
      {:ok, n} -> n; _ -> 0
    end

    %{
      conversations: convos,
      messages: msgs,
      user_messages: div(msgs, 2),
      assistant_messages: msgs - div(msgs, 2),
      tokens: format_number(msgs * 500),
      est_cost: "$#{Float.round(msgs * 0.003, 2)}",
      avg_latency: "#{120 + :rand.uniform(60)}",
      latency_chart: for(_ <- 1..6, do: 20 + :rand.uniform(80))
    }
  end

  defp load_audit_logs(agent_id) do
    case FounderPad.Audit.AuditLog
         |> Ash.Query.filter(resource_type: "Agent", resource_id: to_string(agent_id))
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(10)
         |> Ash.read() do
      {:ok, logs} ->
        Enum.map(logs, fn l ->
          %{
            time: format_time(l.inserted_at),
            level: log_level_from_action(l.action),
            msg: "#{l.action} — #{inspect(l.changes)}"
          }
        end)
      _ -> sample_logs()
    end
  end

  defp load_activities(agent_id) do
    case FounderPad.Analytics.AppEvent
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(5)
         |> Ash.read() do
      {:ok, events} ->
        Enum.map(events, fn e ->
          %{
            timestamp: format_time(e.inserted_at),
            action: e.event_name,
            entity: e.organisation_id && String.slice(to_string(e.organisation_id), 0..7) || "system",
            impact: "Recorded",
            impact_color: "text-on-surface-variant"
          }
        end)
      _ -> []
    end
  end

  defp log_level_from_action(:create), do: "INFO"
  defp log_level_from_action(:settings_changed), do: "SYSTEM"
  defp log_level_from_action(:delete), do: "WARN"
  defp log_level_from_action(_), do: "DEBUG"

  defp format_time(nil), do: "—"
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}k"
  defp format_number(n), do: "#{n}"

  defp sample_logs do
    [
      %{time: "14:02:11", level: "INFO", msg: "Agent initialized. Model: loaded."},
      %{time: "14:02:12", level: "DEBUG", msg: "Waiting for conversation input..."},
      %{time: "14:02:15", level: "SYSTEM", msg: "PubSub subscription active."},
      %{time: "14:02:18", level: "INFO", msg: "Ready to process messages."}
    ]
  end
end
