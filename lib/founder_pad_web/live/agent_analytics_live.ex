defmodule FounderPadWeb.AgentAnalyticsLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(%{"id" => agent_id}, _session, socket) do
    agent =
      FounderPad.AI.Agent
      |> Ash.get!(agent_id)

    metrics = compute_metrics(agent_id)

    {:ok,
     assign(socket,
       active_nav: :agents,
       page_title: "Agent Analytics",
       agent: agent,
       metrics: metrics
     )}
  end

  def handle_event("refresh", _, socket) do
    metrics = compute_metrics(socket.assigns.agent.id)

    {:noreply,
     socket
     |> assign(metrics: metrics)
     |> put_flash(:info, "Analytics refreshed")}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Header --%>
      <section class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <div class="flex items-center gap-2 text-xs font-mono text-on-surface-variant/60 uppercase tracking-widest mb-2">
            <span class="material-symbols-outlined text-sm text-primary">analytics</span>
            Agent Analytics
          </div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">{@agent.name}</h1>
          <p class="text-on-surface-variant mt-1">
            Usage metrics and performance data for this agent.
          </p>
        </div>
        <div class="flex items-center gap-3">
          <a
            href={~p"/agents/#{@agent.id}"}
            class="text-sm text-primary hover:underline flex items-center gap-1"
          >
            <span class="material-symbols-outlined text-sm">arrow_back</span> Back to Agent
          </a>
          <button
            phx-click="refresh"
            class="p-2 text-on-surface-variant hover:text-primary rounded-lg hover:bg-surface-container-high transition-colors"
            title="Refresh"
          >
            <span class="material-symbols-outlined">refresh</span>
          </button>
        </div>
      </section>

      <%!-- Metrics Cards --%>
      <section class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <.metric_card
          label="Total Conversations"
          value={@metrics.conversations_count}
          icon="chat"
          color="primary"
        />
        <.metric_card
          label="Total Messages"
          value={@metrics.messages_count}
          icon="forum"
          color="secondary"
        />
        <.metric_card
          label="Tool Calls"
          value={@metrics.tool_calls_count}
          icon="build"
          color="tertiary"
        />
      </section>

      <section class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <.metric_card
          label="Token Usage"
          value={format_number(@metrics.total_tokens)}
          icon="token"
          color="primary"
        />
        <.metric_card
          label="Total Cost"
          value={format_cost(@metrics.total_cost_cents)}
          icon="payments"
          color="secondary"
        />
        <.metric_card
          label="Avg Response Time"
          value={format_duration(@metrics.avg_duration_ms)}
          icon="speed"
          color="tertiary"
        />
      </section>

      <%!-- Success Rate Section --%>
      <section class="bg-surface-container rounded-lg p-6">
        <h2 class="text-xl font-bold font-headline mb-4">Tool Call Performance</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-6">
          <div>
            <p class="text-xs font-mono text-on-surface-variant uppercase mb-1">Success Rate</p>
            <p class="text-2xl font-mono font-medium text-primary">
              {format_percent(@metrics.success_rate)}
            </p>
          </div>
          <div>
            <p class="text-xs font-mono text-on-surface-variant uppercase mb-1">Completed</p>
            <p class="text-2xl font-mono font-medium text-green-400">{@metrics.completed_count}</p>
          </div>
          <div>
            <p class="text-xs font-mono text-on-surface-variant uppercase mb-1">Failed</p>
            <p class="text-2xl font-mono font-medium text-error">{@metrics.failed_count}</p>
          </div>
          <div>
            <p class="text-xs font-mono text-on-surface-variant uppercase mb-1">Pending</p>
            <p class="text-2xl font-mono font-medium text-on-surface-variant">
              {@metrics.pending_count}
            </p>
          </div>
        </div>
      </section>

      <%!-- Recent Conversations Table --%>
      <section class="space-y-4">
        <h2 class="text-xl font-bold font-headline">Recent Conversations</h2>
        <div class="bg-surface-container-lowest rounded-lg overflow-hidden">
          <%= if @metrics.recent_conversations == [] do %>
            <div class="px-6 py-12 text-center text-on-surface-variant">
              <span class="material-symbols-outlined text-4xl mb-2 block opacity-30">chat</span>
              <p class="text-sm">No conversations yet</p>
            </div>
          <% else %>
            <div class="grid grid-cols-12 gap-4 px-6 py-3 bg-surface-container/30 text-xs font-mono uppercase tracking-widest text-on-surface-variant">
              <div class="col-span-5">Title</div>
              <div class="col-span-2">Messages</div>
              <div class="col-span-2">Status</div>
              <div class="col-span-3">Created</div>
            </div>
            <div
              :for={conv <- @metrics.recent_conversations}
              class="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-surface-container-high/50 transition-colors"
            >
              <div class="col-span-5 text-sm font-medium truncate">{conv.title || "Untitled"}</div>
              <div class="col-span-2 text-sm font-mono text-on-surface-variant">
                {conv.message_count}
              </div>
              <div class="col-span-2">
                <span class={[
                  "px-2 py-0.5 rounded text-[10px] font-bold uppercase",
                  if(conv.status == :active,
                    do: "bg-primary/10 text-primary",
                    else: "bg-on-surface-variant/10 text-on-surface-variant"
                  )
                ]}>
                  {conv.status}
                </span>
              </div>
              <div class="col-span-3 text-xs font-mono text-on-surface-variant">
                {Calendar.strftime(conv.inserted_at, "%Y-%m-%d %H:%M")}
              </div>
            </div>
          <% end %>
        </div>
      </section>
    </div>
    """
  end

  # ── Components ──

  defp metric_card(assigns) do
    ~H"""
    <div class="bg-surface-container p-6 rounded-lg relative overflow-hidden group">
      <div class="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
        <span class="material-symbols-outlined text-5xl">{@icon}</span>
      </div>
      <p class="text-sm font-medium text-on-surface-variant mb-3">{@label}</p>
      <span class={"text-4xl font-mono font-medium text-#{@color}"}>{@value}</span>
    </div>
    """
  end

  # ── Metrics Computation ──

  defp compute_metrics(agent_id) do
    conversations = load_conversations(agent_id)
    conversation_ids = Enum.map(conversations, & &1.id)
    messages = load_messages(conversation_ids)
    message_ids = Enum.map(messages, & &1.id)
    tool_calls = load_tool_calls(message_ids)

    total_tokens = Enum.sum(Enum.map(messages, & &1.token_count))
    total_cost_cents = Enum.sum(Enum.map(messages, & &1.cost_cents))

    completed_count = Enum.count(tool_calls, &(&1.status == :completed))
    failed_count = Enum.count(tool_calls, &(&1.status == :failed))
    pending_count = Enum.count(tool_calls, &(&1.status in [:pending, :running]))
    tool_calls_count = length(tool_calls)

    success_rate =
      if tool_calls_count > 0 do
        Float.round(completed_count / tool_calls_count * 100, 1)
      else
        0.0
      end

    durations =
      tool_calls
      |> Enum.map(& &1.duration_ms)
      |> Enum.reject(&is_nil/1)

    avg_duration_ms =
      if durations != [] do
        round(Enum.sum(durations) / length(durations))
      else
        nil
      end

    # Build recent conversations with message counts
    message_counts_by_conv =
      messages
      |> Enum.group_by(& &1.conversation_id)
      |> Map.new(fn {cid, msgs} -> {cid, length(msgs)} end)

    recent_conversations =
      conversations
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
      |> Enum.take(10)
      |> Enum.map(fn conv ->
        %{
          title: conv.title,
          status: conv.status,
          inserted_at: conv.inserted_at,
          message_count: Map.get(message_counts_by_conv, conv.id, 0)
        }
      end)

    %{
      conversations_count: length(conversations),
      messages_count: length(messages),
      tool_calls_count: tool_calls_count,
      total_tokens: total_tokens,
      total_cost_cents: total_cost_cents,
      avg_duration_ms: avg_duration_ms,
      success_rate: success_rate,
      completed_count: completed_count,
      failed_count: failed_count,
      pending_count: pending_count,
      recent_conversations: recent_conversations
    }
  end

  defp load_conversations(agent_id) do
    case FounderPad.AI.Conversation
         |> Ash.Query.filter(agent_id: agent_id)
         |> Ash.read() do
      {:ok, conversations} -> conversations
      _ -> []
    end
  end

  defp load_messages([]), do: []

  defp load_messages(conversation_ids) do
    case FounderPad.AI.Message
         |> Ash.Query.filter(conversation_id in ^conversation_ids)
         |> Ash.read() do
      {:ok, messages} -> messages
      _ -> []
    end
  end

  defp load_tool_calls([]), do: []

  defp load_tool_calls(message_ids) do
    case FounderPad.AI.ToolCall
         |> Ash.Query.filter(message_id in ^message_ids)
         |> Ash.read() do
      {:ok, tool_calls} -> tool_calls
      _ -> []
    end
  end

  # ── Formatters ──

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}k"
  defp format_number(n), do: "#{n}"

  defp format_cost(cents) when cents >= 100, do: "$#{Float.round(cents / 100, 2)}"
  defp format_cost(cents), do: "$0.#{String.pad_leading(to_string(cents), 2, "0")}"

  defp format_duration(nil), do: "—"
  defp format_duration(ms) when ms >= 1_000, do: "#{Float.round(ms / 1_000, 1)}s"
  defp format_duration(ms), do: "#{ms}ms"

  defp format_percent(rate) when rate == 0.0, do: "0.0%"
  defp format_percent(rate), do: "#{rate}%"
end
