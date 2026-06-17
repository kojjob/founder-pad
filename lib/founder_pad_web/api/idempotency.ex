defmodule FounderPadWeb.Api.Idempotency do
  @moduledoc """
  Shared Idempotency-Key handling for `/v1` write endpoints.

  `handle/4` takes a zero-arity `resolve` that returns `{status, body_map}` and
  performs the side effects (audit, webhooks). When an `Idempotency-Key` header is
  present, the same key+body replays the cached response, a different body returns
  `409 duplicate_idempotency_key`, and only successful (2xx) responses are cached —
  so a replay never repeats side effects.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias FounderPad.Compliance
  alias FounderPadWeb.Api.{Errors, RequestId}

  @type resolver :: (-> {pos_integer(), map()})

  @spec handle(Plug.Conn.t(), map(), map(), resolver()) :: Plug.Conn.t()
  def handle(conn, org, params, resolve) do
    case key(conn) do
      nil ->
        {status, body} = resolve.()
        respond(conn, status, body)

      idem ->
        with_idempotency(conn, org, idem, params, resolve)
    end
  end

  @doc "Render a `{status, body}` pair as JSON."
  def respond(conn, status, body), do: conn |> put_status(status) |> json(body)

  defp with_idempotency(conn, org, idem, params, resolve) do
    fingerprint = fingerprint(params)

    case lookup(org, idem) do
      nil ->
        {status, body} = resolve.()
        maybe_store(org, idem, fingerprint, status, body)
        respond(conn, status, body)

      %{request_fingerprint: ^fingerprint} = record ->
        respond(conn, record.response_status, record.response_body)

      _record ->
        respond(
          conn,
          409,
          Errors.body(
            conn,
            "duplicate_idempotency_key",
            "This Idempotency-Key was already used with a different request body."
          )
        )
    end
  end

  defp key(conn) do
    case get_req_header(conn, "idempotency-key") do
      [k | _] when k != "" -> k
      _ -> nil
    end
  end

  # Content fingerprint independent of map key ordering.
  defp fingerprint(params) do
    :crypto.hash(:sha256, :erlang.term_to_binary(params, [:deterministic]))
    |> Base.encode16(case: :lower)
  end

  defp lookup(org, idem) do
    case Compliance.find_idempotency_key(org.id, idem) do
      {:ok, record} -> record
      _ -> nil
    end
  end

  defp maybe_store(org, key, fingerprint, status, body) when status in 200..299 do
    Compliance.create_idempotency_key(%{
      organisation_id: org.id,
      key: key,
      request_fingerprint: fingerprint,
      response_status: status,
      response_body: jsonable(body)
    })
  rescue
    _ -> :ok
  end

  defp maybe_store(_org, _key, _fingerprint, _status, _body), do: :ok

  defp jsonable(body), do: body |> Jason.encode!() |> Jason.decode!()
end
