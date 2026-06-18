defmodule FounderPadWeb.Api.V1.WebhookController do
  @moduledoc """
  Developer-facing webhook management on `/v1`: register endpoints, inspect
  deliveries, and retry a delivery. The signing secret is generated server-side and
  returned **once** on creation; it is never echoed in listings.
  """
  use FounderPadWeb, :controller
  require Ash.Query

  alias FounderPad.Webhooks.{OutboundWebhook, WebhookDelivery}
  alias FounderPadWeb.Api.{Errors, Idempotency, Pagination, RequestId}

  plug :require_scope, "write" when action in [:create_endpoint, :retry_delivery]
  plug :require_scope, "read" when action in [:list_endpoints, :list_deliveries]

  def create_endpoint(conn, params) do
    org = conn.assigns.current_organisation
    secret = "whsec_" <> (:crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false))

    case OutboundWebhook
         |> Ash.Changeset.for_create(:create, %{
           url: Map.get(params, "url"),
           secret: secret,
           events: Map.get(params, "events", []),
           organisation_id: org.id
         })
         |> Ash.create() do
      {:ok, wh} ->
        Idempotency.respond(conn, 201, %{
          id: wh.id,
          url: wh.url,
          events: wh.events,
          active: wh.active,
          # Shown once — store it now; it is never returned again.
          secret: secret
        })

      {:error, %Ash.Error.Invalid{} = error} ->
        Errors.send(conn, 422, "validation_failed", Exception.message(error))
    end
  end

  def list_endpoints(conn, params) do
    org = conn.assigns.current_organisation
    {limit, offset} = Pagination.parse(params)

    data =
      OutboundWebhook
      |> Ash.Query.filter(organisation_id == ^org.id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(limit)
      |> Ash.Query.offset(offset)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&endpoint_item/1)

    Idempotency.respond(conn, 200, %{data: data, pagination: %{limit: limit, offset: offset}})
  end

  def list_deliveries(conn, params) do
    org = conn.assigns.current_organisation
    {limit, offset} = Pagination.parse(params)

    case owned_endpoint(Map.get(params, "webhook_endpoint_id"), org) do
      {:ok, wh} ->
        data =
          WebhookDelivery
          |> Ash.Query.filter(webhook_id == ^wh.id)
          |> Ash.Query.sort(inserted_at: :desc)
          |> Ash.Query.limit(limit)
          |> Ash.Query.offset(offset)
          |> Ash.read!(authorize?: false)
          |> Enum.map(&delivery_item/1)

        Idempotency.respond(conn, 200, %{data: data, pagination: %{limit: limit, offset: offset}})

      :error ->
        Errors.send(conn, 404, "webhook_endpoint_not_found", "No webhook endpoint with that id.")
    end
  end

  def retry_delivery(conn, %{"id" => id}) do
    org = conn.assigns.current_organisation

    case load_owned_delivery(id, org) do
      {:ok, delivery, wh} ->
        %{
          webhook_id: wh.id,
          event_type: delivery.event_type,
          payload: delivery.payload,
          url: wh.url,
          secret: wh.secret
        }
        |> FounderPad.Webhooks.Workers.WebhookDeliveryWorker.new()
        |> Oban.insert()

        Idempotency.respond(conn, 202, %{id: delivery.id, status: "retrying"})

      :error ->
        Errors.send(conn, 404, "delivery_not_found", "No webhook delivery with that id.")
    end
  end

  defp owned_endpoint(nil, _org), do: :error

  defp owned_endpoint(id, org) do
    case Ash.get(OutboundWebhook, id, authorize?: false) do
      {:ok, %{organisation_id: org_id} = wh} when org_id == org.id -> {:ok, wh}
      _ -> :error
    end
  end

  defp load_owned_delivery(id, org) do
    with {:ok, delivery} <- Ash.get(WebhookDelivery, id, authorize?: false),
         {:ok, wh} <- owned_endpoint(delivery.webhook_id, org) do
      {:ok, delivery, wh}
    else
      _ -> :error
    end
  end

  defp endpoint_item(wh) do
    %{id: wh.id, url: wh.url, events: wh.events, active: wh.active, created_at: wh.inserted_at}
  end

  defp delivery_item(d) do
    %{
      id: d.id,
      event_type: d.event_type,
      status: d.status,
      attempts: d.attempts,
      response_status: d.response_status,
      created_at: d.inserted_at
    }
  end

  defp require_scope(conn, scope) do
    scopes = conn.assigns.api_key.scopes
    wanted = String.to_existing_atom(scope)

    if wanted in scopes or :admin in scopes do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{
        error: %{
          code: "permission_denied",
          message: "This API key lacks the required `#{scope}` scope.",
          request_id: RequestId.get(conn)
        }
      })
      |> halt()
    end
  end
end
