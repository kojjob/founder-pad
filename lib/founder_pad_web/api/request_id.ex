defmodule FounderPadWeb.Api.RequestId do
  @moduledoc "Stable per-request identifier surfaced in API responses and errors."

  @doc "Return the request id for this conn, deriving a `req_`-prefixed one if absent."
  def get(conn) do
    case Plug.Conn.get_resp_header(conn, "x-request-id") do
      [id | _] -> id
      _ -> "req_" <> (Ash.UUID.generate() |> String.replace("-", "") |> String.slice(0, 20))
    end
  end
end
