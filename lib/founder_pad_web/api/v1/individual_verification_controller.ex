defmodule FounderPadWeb.Api.V1.IndividualVerificationController do
  @moduledoc """
  Public REST endpoints for individual (person) identity verification.

  Contract per `API_SPEC.md`: plain JSON (not JSON:API), nested `person`/`consent`/
  `options`, deterministic sandbox outcomes, idempotency on `external_id`, and
  stable error codes. The verification mode (`test`/`live`) is inherited from the
  presented API key.
  """
  use FounderPadWeb, :controller
  require Ash.Query

  alias FounderPad.Compliance
  alias FounderPad.Compliance.{IndividualVerification, Verifications}
  alias FounderPadWeb.Api.{Errors, Idempotency, RequestId}

  plug :require_scope, "write" when action in [:create]
  plug :require_scope, "read" when action in [:show]

  def create(conn, params) do
    org = conn.assigns.current_organisation
    Idempotency.handle(conn, org, params, fn -> resolve(conn, org, params) end)
  end

  def show(conn, %{"id" => id}) do
    org = conn.assigns.current_organisation

    case Ash.get(IndividualVerification, id, authorize?: false) do
      {:ok, %{organisation_id: org_id} = ivf} when org_id == org.id ->
        Idempotency.respond(conn, 200, detail(ivf))

      _ ->
        Errors.send(conn, 404, "verification_not_found", "No verification with that id.")
    end
  end

  # Returns {status, body_map}. Side effects (audit, webhook) happen here, so a
  # cached replay never repeats them.
  defp resolve(conn, org, params) do
    mode = conn.assigns.api_key.mode
    person = Map.get(params, "person", %{})
    card = Map.get(person, "ghana_card_number")

    cond do
      is_nil(card) or card == "" ->
        {422, Errors.body(conn, "validation_failed", "person.ghana_card_number is required.")}

      existing = idempotent_match(org, Map.get(params, "external_id")) ->
        {200, detail(existing)}

      true ->
        create_and_process(conn, org, mode, params, person, card)
    end
  end

  defp create_and_process(conn, org, mode, params, person, card) do
    with {:ok, consent_id} <- resolve_consent(conn, org, mode, params),
         {:ok, ivf} <- build_verification(org, mode, params, person, card, consent_id) do
      audit(conn, "individual_verification.created", ivf, %{mode: mode})
      maybe_audit_consent(conn, org, consent_id)
      processed = process_or_keep(ivf, card)
      audit(conn, "individual_verification.completed", processed, %{status: processed.status})
      dispatch_webhook(org, processed)
      {201, summary(processed)}
    else
      {:error, :consent_required} ->
        {422, consent_required_error(conn)}

      {:error, %Ash.Error.Invalid{} = error} ->
        if consent_error?(error) do
          {422, consent_required_error(conn)}
        else
          {422, Errors.body(conn, "validation_failed", Exception.message(error))}
        end
    end
  end

  defp consent_required_error(conn) do
    Errors.body(
      conn,
      "consent_required",
      "A consent receipt is required before live identity verification."
    )
  end

  # Live mode must carry consent; create the receipt from the inline block if given.
  defp resolve_consent(_conn, _org, :test, _params), do: {:ok, nil}

  defp resolve_consent(_conn, org, :live, params) do
    case Map.get(params, "consent") do
      consent when is_map(consent) ->
        attrs = %{
          organisation_id: org.id,
          external_subject_id: Map.get(params, "external_id"),
          purpose: Map.get(consent, "purpose", "identity_verification"),
          channel: parse_channel(Map.get(consent, "channel")),
          privacy_notice_version: Map.get(consent, "privacy_notice_version"),
          accepted_at: parse_datetime(Map.get(consent, "accepted_at"))
        }

        case Compliance.create_consent_receipt(attrs) do
          {:ok, receipt} -> {:ok, receipt.id}
          error -> error
        end

      _ ->
        {:error, :consent_required}
    end
  end

  defp build_verification(org, mode, params, person, card, consent_id) do
    IndividualVerification
    |> Ash.Changeset.for_create(:create, %{
      organisation_id: org.id,
      external_id: Map.get(params, "external_id"),
      mode: mode,
      consent_receipt_id: consent_id,
      ghana_card_number: card,
      first_name: Map.get(person, "first_name"),
      last_name: Map.get(person, "last_name"),
      date_of_birth: parse_date(Map.get(person, "date_of_birth")),
      phone_number: Map.get(person, "phone_number")
    })
    |> Ash.create()
  end

  # Sandbox processing is synchronous; a provider outage leaves the check pending.
  defp process_or_keep(ivf, card) do
    case Verifications.process(ivf, card) do
      {:ok, processed} -> processed
      {:error, _reason} -> ivf
    end
  end

  defp idempotent_match(_org, nil), do: nil
  defp idempotent_match(_org, ""), do: nil

  defp idempotent_match(org, external_id) do
    IndividualVerification
    |> Ash.Query.for_read(:by_organisation, %{organisation_id: org.id})
    |> Ash.Query.filter(external_id == ^external_id)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  # Emit an immutable audit event for an API-key-driven action. The semantic
  # event name is carried in metadata; actor_id is nil because the actor is an
  # API key (recorded via metadata) rather than a logged-in user.
  defp audit(conn, event, ivf, extra) do
    metadata =
      Map.merge(extra, %{
        event: event,
        actor_type: "api_key",
        api_key_id: conn.assigns.api_key.id,
        request_id: RequestId.get(conn)
      })

    FounderPad.Audit.log(
      audit_action(event),
      "IndividualVerification",
      ivf.id,
      nil,
      ivf.organisation_id,
      metadata: metadata,
      ip_address: client_ip(conn),
      user_agent: user_agent(conn)
    )
  end

  # Emit the lifecycle webhook for a completed check. `requires_review` is its own
  # event so subscribers can route review-needed cases differently. Pending checks
  # (provider outage) emit nothing — they have not reached a terminal state.
  defp dispatch_webhook(_org, %{status: :pending}), do: :ok
  defp dispatch_webhook(_org, %{status: :processing}), do: :ok

  defp dispatch_webhook(org, ivf) do
    event_type = webhook_event(ivf.status)

    payload = %{
      id: "evt_" <> (Ash.UUID.generate() |> String.replace("-", "") |> String.slice(0, 20)),
      type: event_type,
      created_at: DateTime.utc_now(),
      data: %{id: ivf.id, status: ivf.status, external_id: ivf.external_id}
    }

    FounderPad.Webhooks.dispatch(org.id, event_type, payload)
  end

  defp webhook_event(:requires_review), do: "individual_verification.requires_review"
  defp webhook_event(_), do: "individual_verification.completed"

  defp maybe_audit_consent(_conn, _org, nil), do: :ok

  defp maybe_audit_consent(conn, org, consent_id) do
    FounderPad.Audit.log(:create, "ConsentReceipt", consent_id, nil, org.id,
      metadata: %{
        event: "consent_receipt.captured",
        actor_type: "api_key",
        api_key_id: conn.assigns.api_key.id
      },
      ip_address: client_ip(conn),
      user_agent: user_agent(conn)
    )
  end

  defp audit_action("individual_verification.completed"), do: :update
  defp audit_action(_), do: :create

  defp client_ip(conn) do
    conn.remote_ip |> :inet.ntoa() |> to_string()
  rescue
    _ -> nil
  end

  defp user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      _ -> nil
    end
  end

  defp summary(ivf) do
    %{
      id: ivf.id,
      status: ivf.status,
      mode: ivf.mode,
      external_id: ivf.external_id,
      created_at: ivf.inserted_at,
      links: %{self: "/v1/individual_verifications/#{ivf.id}"}
    }
  end

  defp detail(ivf) do
    %{
      id: ivf.id,
      status: ivf.status,
      mode: ivf.mode,
      external_id: ivf.external_id,
      identity: %{
        verified: ivf.identity_verified,
        match_level: ivf.match_level,
        provider_reference: ivf.provider_reference
      },
      risk: %{
        level: ivf.risk_level,
        score: ivf.risk_score,
        reason_codes: ivf.reason_codes
      },
      consent_receipt_id: ivf.consent_receipt_id,
      created_at: ivf.inserted_at,
      completed_at: ivf.completed_at
    }
  end

  defp consent_error?(%Ash.Error.Invalid{} = error) do
    Exception.message(error) =~ "consent"
  end

  defp parse_channel(nil), do: :api

  defp parse_channel(value) when value in ~w(web mobile ussd sms api),
    do: String.to_existing_atom(value)

  defp parse_channel(_), do: :api

  defp parse_datetime(nil), do: DateTime.utc_now()

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  # Scope guard plug: requires the named scope (or :admin) on the presented key.
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
