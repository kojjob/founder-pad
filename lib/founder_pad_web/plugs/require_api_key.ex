defmodule FounderPadWeb.Plugs.RequireApiKey do
  @moduledoc """
  Rejects requests on the public `/v1` API that did not present a valid API key.

  Runs after `FounderPadWeb.Plugs.ApiKeyAuth` (which authenticates and assigns the
  key when present). This plug turns the absence of a key into a 401 so protected
  endpoints never run unauthenticated.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:api_key] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: %{
            code: "authentication_failed",
            message: "A valid API key is required. Pass it as `Authorization: Bearer <key>`.",
            request_id: FounderPadWeb.Api.RequestId.get(conn)
          }
        })
        |> halt()

      _key ->
        conn
    end
  end
end
