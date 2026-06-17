defmodule FounderPadWeb.Api.Errors do
  @moduledoc "Renders the GhanaTrust public API error envelope with a stable code."
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias FounderPadWeb.Api.RequestId

  @doc "Send a `{error: {code, message, request_id}}` body with the given HTTP status."
  def send(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{
      error: %{
        code: code,
        message: message,
        request_id: RequestId.get(conn)
      }
    })
    |> halt()
  end
end
