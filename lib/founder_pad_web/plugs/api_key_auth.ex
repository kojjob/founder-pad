defmodule FounderPadWeb.Plugs.ApiKeyAuth do
  @moduledoc "Authenticates API requests via API key in Authorization header."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         hash <- :crypto.hash(:sha256, token) |> Base.encode16(case: :lower),
         [api_key] <-
           FounderPad.ApiKeys.ApiKey
           |> Ash.Query.for_read(:by_key_hash, %{hash: hash})
           |> Ash.Query.load([:organisation])
           |> Ash.read!() do
      Task.start(fn ->
        api_key
        |> Ash.Changeset.for_update(:touch_last_used, %{})
        |> Ash.update()
      end)

      conn
      |> assign(:api_key, api_key)
      |> assign(:current_organisation, api_key.organisation)
    else
      _ -> conn
    end
  end
end
