defmodule FounderPadWeb.Api.V1.BusinessVerificationController do
  @moduledoc """
  Public REST endpoints for business (KYB) verification. Mirrors individual
  verification: plain JSON, deterministic sandbox outcomes, idempotency, stable
  error codes, mode inherited from the API key. Side effects (audit, webhook) run
  in `resolve/3` so idempotent replays never repeat them.
  """
  use FounderPadWeb, :controller
  require Ash.Query

  alias FounderPad.Compliance.{AmlScreening, BusinessVerification, KybVerifications, Metering}
  alias FounderPadWeb.Api.{Errors, Idempotency, RequestId}

  plug :require_scope, "write" when action in [:create]
  plug :require_scope, "read" when action in [:show, :index]

  def create(conn, params) do
    org = conn.assigns.current_organisation
    Idempotency.handle(conn, org, params, fn -> resolve(conn, org, params) end)
  end

  def index(conn, params) do
    org = conn.assigns.current_organisation
    {limit, offset} = FounderPadWeb.Api.Pagination.parse(params)

    data =
      BusinessVerification
      |> Ash.Query.for_read(:by_organisation, %{organisation_id: org.id})
      |> FounderPadWeb.Api.Pagination.maybe_filter_status(params)
      |> Ash.Query.limit(limit)
      |> Ash.Query.offset(offset)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&list_item/1)

    Idempotency.respond(conn, 200, %{data: data, pagination: %{limit: limit, offset: offset}})
  end

  def show(conn, %{"id" => id}) do
    org = conn.assigns.current_organisation

    case Ash.get(BusinessVerification, id, authorize?: false) do
      {:ok, %{organisation_id: org_id} = bv} when org_id == org.id ->
        Idempotency.respond(conn, 200, detail(bv))

      _ ->
        Errors.send(
          conn,
          404,
          "business_verification_not_found",
          "No business verification with that id."
        )
    end
  end

  defp resolve(conn, org, params) do
    mode = conn.assigns.api_key.mode
    business = Map.get(params, "business", %{})
    reg = Map.get(business, "registration_number")

    cond do
      is_nil(reg) or reg == "" ->
        {422, Errors.body(conn, "validation_failed", "business.registration_number is required.")}

      existing = idempotent_match(org, Map.get(params, "external_id")) ->
        {200, detail(existing)}

      true ->
        create_and_process(conn, org, mode, params, business, reg)
    end
  end

  defp create_and_process(conn, org, mode, params, business, reg) do
    case build(org, mode, params, business, reg) do
      {:ok, bv} ->
        audit(conn, "business_verification.created", bv, %{mode: mode})
        processed = process_or_keep(bv, reg)
        audit(conn, "business_verification.completed", processed, %{status: processed.status})
        dispatch_webhook(org, processed)
        maybe_run_aml(conn, org, processed, Map.get(business, "registered_name"), params)
        Metering.meter(org.id, "business_verification", mode)
        {201, summary(processed)}

      {:error, %Ash.Error.Invalid{} = error} ->
        {422, Errors.body(conn, "validation_failed", Exception.message(error))}
    end
  end

  defp build(org, mode, params, business, reg) do
    BusinessVerification
    |> Ash.Changeset.for_create(:create, %{
      organisation_id: org.id,
      external_id: Map.get(params, "external_id"),
      mode: mode,
      registered_name: Map.get(business, "registered_name"),
      registration_number: reg,
      tin: Map.get(business, "tin")
    })
    |> Ash.create()
  end

  defp process_or_keep(bv, reg) do
    case KybVerifications.process(bv, reg) do
      {:ok, processed} -> processed
      {:error, _reason} -> bv
    end
  end

  defp idempotent_match(_org, nil), do: nil
  defp idempotent_match(_org, ""), do: nil

  defp idempotent_match(org, external_id) do
    BusinessVerification
    |> Ash.Query.for_read(:by_organisation, %{organisation_id: org.id})
    |> Ash.Query.filter(external_id == ^external_id)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp dispatch_webhook(_org, %{status: status}) when status in [:pending, :processing], do: :ok

  defp dispatch_webhook(org, bv) do
    event_type = webhook_event(bv.status)

    payload = %{
      id: "evt_" <> (Ash.UUID.generate() |> String.replace("-", "") |> String.slice(0, 20)),
      type: event_type,
      created_at: DateTime.utc_now(),
      data: %{id: bv.id, status: bv.status, external_id: bv.external_id}
    }

    FounderPad.Webhooks.dispatch(org.id, event_type, payload)
  end

  defp webhook_event(:requires_review), do: "business_verification.requires_review"
  defp webhook_event(_), do: "business_verification.completed"

  defp audit(conn, event, bv, extra) do
    metadata =
      Map.merge(extra, %{
        event: event,
        actor_type: "api_key",
        api_key_id: conn.assigns.api_key.id,
        request_id: RequestId.get(conn)
      })

    FounderPad.Audit.log(
      audit_action(event),
      "BusinessVerification",
      bv.id,
      nil,
      bv.organisation_id,
      metadata: metadata
    )
  end

  defp audit_action("business_verification.completed"), do: :update
  defp audit_action(_), do: :create

  defp maybe_run_aml(conn, org, bv, name, params) do
    if get_in(params, ["options", "run_aml_screen"]) == true and name not in [nil, ""] do
      case AmlScreening.screen(org.id, :business, bv.id, name) do
        {:ok, screen} ->
          FounderPad.Audit.log(:create, "AmlScreen", screen.id, nil, org.id,
            metadata: %{
              event: "aml_screen.completed",
              actor_type: "api_key",
              api_key_id: conn.assigns.api_key.id,
              status: screen.status
            }
          )

          Metering.meter(org.id, "aml_screen", conn.assigns.api_key.mode)

        _ ->
          :ok
      end
    end
  end

  defp list_item(bv) do
    %{
      id: bv.id,
      status: bv.status,
      mode: bv.mode,
      external_id: bv.external_id,
      registered_name: bv.registered_name,
      risk_level: bv.risk_level,
      created_at: bv.inserted_at
    }
  end

  defp summary(bv) do
    %{
      id: bv.id,
      status: bv.status,
      mode: bv.mode,
      external_id: bv.external_id,
      created_at: bv.inserted_at,
      links: %{self: "/v1/business_verifications/#{bv.id}"}
    }
  end

  defp detail(bv) do
    %{
      id: bv.id,
      status: bv.status,
      mode: bv.mode,
      external_id: bv.external_id,
      business: %{registered_name: bv.registered_name},
      risk: %{level: bv.risk_level, reason_codes: bv.reason_codes},
      provider_reference: bv.provider_reference,
      created_at: bv.inserted_at,
      completed_at: bv.completed_at
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
