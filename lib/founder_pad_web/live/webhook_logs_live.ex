defmodule FounderPadWeb.WebhookLogsLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    webhooks = load_webhooks()

    {:ok,
     assign(socket,
       active_nav: :webhooks,
       page_title: "Webhook Logs",
       webhooks: webhooks,
       expanded_webhook_id: nil,
       deliveries: []
     )}
  end

  def handle_event("toggle_webhook", %{"id" => webhook_id}, socket) do
    if socket.assigns.expanded_webhook_id == webhook_id do
      {:noreply, assign(socket, expanded_webhook_id: nil, deliveries: [])}
    else
      deliveries = load_deliveries(webhook_id)
      {:noreply, assign(socket, expanded_webhook_id: webhook_id, deliveries: deliveries)}
    end
  end

  def handle_event("retry", %{"id" => delivery_id}, socket) do
    delivery = Enum.find(socket.assigns.deliveries, &(&1.id == delivery_id))

    if delivery do
      webhook =
        Enum.find(socket.assigns.webhooks, &(&1.id == delivery.webhook_id))

      if webhook do
        %{
          webhook_id: webhook.id,
          event_type: delivery.event_type,
          payload: delivery.payload,
          url: webhook.url,
          secret: webhook.secret
        }
        |> FounderPad.Webhooks.Workers.WebhookDeliveryWorker.new()
        |> Oban.insert()

        deliveries = load_deliveries(socket.assigns.expanded_webhook_id)

        {:noreply,
         socket
         |> assign(deliveries: deliveries)
         |> put_flash(:info, "Delivery re-enqueued for retry")}
      else
        {:noreply, put_flash(socket, :error, "Webhook not found")}
      end
    else
      {:noreply, put_flash(socket, :error, "Delivery not found")}
    end
  end

  def handle_event("refresh", _, socket) do
    webhooks = load_webhooks()

    deliveries =
      if socket.assigns.expanded_webhook_id do
        load_deliveries(socket.assigns.expanded_webhook_id)
      else
        []
      end

    {:noreply,
     socket
     |> assign(webhooks: webhooks, deliveries: deliveries)
     |> put_flash(:info, "Webhook logs refreshed")}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Header --%>
      <section class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <div class="flex items-center gap-2 text-xs font-mono text-on-surface-variant/60 uppercase tracking-widest mb-2">
            <span class="material-symbols-outlined text-sm text-primary">webhook</span> Webhook Logs
          </div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight">Outbound Webhooks</h1>
          <p class="text-on-surface-variant mt-1">Monitor webhook deliveries and inspect payloads.</p>
        </div>
        <button
          phx-click="refresh"
          class="p-2 text-on-surface-variant hover:text-primary rounded-lg hover:bg-surface-container-high transition-colors"
          title="Refresh"
        >
          <span class="material-symbols-outlined">refresh</span>
        </button>
      </section>

      <%!-- Empty State --%>
      <div :if={@webhooks == []} class="text-center py-16">
        <span class="material-symbols-outlined text-6xl text-on-surface-variant/30 mb-4 block">
          webhook
        </span>
        <h3 class="text-xl font-bold font-headline text-on-surface mb-2">No webhooks configured</h3>
        <p class="text-on-surface-variant">
          Webhooks will appear here once configured for your organisation.
        </p>
      </div>

      <%!-- Webhooks List --%>
      <div :if={@webhooks != []} class="space-y-4">
        <div :for={webhook <- @webhooks} class="bg-surface-container rounded-lg overflow-hidden">
          <%!-- Webhook Header Row --%>
          <button
            phx-click="toggle_webhook"
            phx-value-id={webhook.id}
            class="w-full px-6 py-4 flex items-center justify-between hover:bg-surface-container-high/50 transition-colors"
          >
            <div class="flex items-center gap-4">
              <div class={"w-10 h-10 rounded-lg flex items-center justify-center #{if webhook.active, do: "bg-primary/10", else: "bg-on-surface-variant/10"}"}>
                <span class={"material-symbols-outlined #{if webhook.active, do: "text-primary", else: "text-on-surface-variant"}"}>
                  webhook
                </span>
              </div>
              <div class="text-left">
                <p class="font-mono text-sm font-medium">{webhook.url}</p>
                <p class="text-xs text-on-surface-variant mt-0.5">
                  Events: {Enum.join(webhook.events, ", ")}
                </p>
              </div>
            </div>
            <div class="flex items-center gap-3">
              <span class={[
                "px-2 py-0.5 rounded text-[10px] font-bold uppercase",
                if(webhook.active,
                  do: "bg-primary/10 text-primary",
                  else: "bg-on-surface-variant/10 text-on-surface-variant"
                )
              ]}>
                {if webhook.active, do: "Active", else: "Inactive"}
              </span>
              <span class="material-symbols-outlined text-on-surface-variant text-lg">
                {if @expanded_webhook_id == webhook.id, do: "expand_less", else: "expand_more"}
              </span>
            </div>
          </button>

          <%!-- Delivery History (Expanded) --%>
          <div :if={@expanded_webhook_id == webhook.id} class="border-t border-outline-variant/20">
            <%= if @deliveries == [] do %>
              <div class="px-6 py-8 text-center text-on-surface-variant">
                <p class="text-sm">No deliveries recorded yet</p>
              </div>
            <% else %>
              <div class="grid grid-cols-12 gap-4 px-6 py-3 bg-surface-container-highest/20 text-xs font-mono uppercase tracking-widest text-on-surface-variant">
                <div class="col-span-3">Event</div>
                <div class="col-span-2">Status</div>
                <div class="col-span-1">HTTP</div>
                <div class="col-span-1">Tries</div>
                <div class="col-span-3">Payload</div>
                <div class="col-span-2">Actions</div>
              </div>
              <div
                :for={delivery <- @deliveries}
                class="grid grid-cols-12 gap-4 px-6 py-3 items-start border-t border-outline-variant/10 hover:bg-surface-container-high/30 transition-colors"
              >
                <div class="col-span-3">
                  <p class="text-sm font-mono">{delivery.event_type}</p>
                  <p class="text-xs text-on-surface-variant mt-0.5">
                    {format_time(delivery.inserted_at)}
                  </p>
                </div>
                <div class="col-span-2">
                  <.delivery_status_badge status={delivery.status} />
                </div>
                <div class="col-span-1 text-sm font-mono text-on-surface-variant">
                  {delivery.response_status || "—"}
                </div>
                <div class="col-span-1 text-sm font-mono text-on-surface-variant">
                  {delivery.attempts}
                </div>
                <div class="col-span-3">
                  <pre class="text-xs font-mono text-on-surface-variant bg-surface-container-highest/30 rounded p-2 overflow-x-auto max-h-24">{format_payload(delivery.payload)}</pre>
                  <p :if={delivery.error} class="text-xs text-error mt-1">Error: {delivery.error}</p>
                </div>
                <div class="col-span-2">
                  <button
                    :if={delivery.status == :failed}
                    phx-click="retry"
                    phx-value-id={delivery.id}
                    class="px-3 py-1 text-xs font-medium rounded bg-primary/10 text-primary hover:bg-primary/20 transition-colors"
                  >
                    Retry
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Components ──

  defp delivery_status_badge(%{status: :delivered} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-green-500/10 text-green-400 text-[10px] font-bold uppercase">
      <span class="w-1.5 h-1.5 rounded-full bg-green-400"></span> Delivered
    </span>
    """
  end

  defp delivery_status_badge(%{status: :failed} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-error/10 text-error text-[10px] font-bold uppercase">
      <span class="w-1.5 h-1.5 rounded-full bg-error"></span> Failed
    </span>
    """
  end

  defp delivery_status_badge(%{status: :pending} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-secondary/10 text-secondary text-[10px] font-bold uppercase">
      <span class="w-1.5 h-1.5 rounded-full bg-secondary animate-pulse"></span> Pending
    </span>
    """
  end

  defp delivery_status_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-on-surface-variant/10 text-on-surface-variant text-[10px] font-bold uppercase">
      <span class="w-1.5 h-1.5 rounded-full bg-on-surface-variant/50"></span> Unknown
    </span>
    """
  end

  # ── Data Loaders ──

  defp load_webhooks do
    case FounderPad.Webhooks.OutboundWebhook
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.read() do
      {:ok, webhooks} -> webhooks
      _ -> []
    end
  end

  defp load_deliveries(webhook_id) do
    case FounderPad.Webhooks.WebhookDelivery
         |> Ash.Query.filter(webhook_id: webhook_id)
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(50)
         |> Ash.read() do
      {:ok, deliveries} -> deliveries
      _ -> []
    end
  end

  # ── Formatters ──

  defp format_payload(nil), do: "{}"
  defp format_payload(payload) when payload == %{}, do: "{}"

  defp format_payload(payload) do
    Jason.encode!(payload, pretty: true)
  end

  defp format_time(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end
end
