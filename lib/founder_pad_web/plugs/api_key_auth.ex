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
      touch_last_used(api_key)

      conn
      |> assign(:api_key, api_key)
      |> assign(:current_organisation, api_key.organisation)
    else
      _ -> conn
    end
  end

  # Async in prod/dev (don't block the request); synchronous in test so the update
  # stays inside the SQL sandbox instead of racing it from an unowned process.
  defp touch_last_used(api_key) do
    update = fn ->
      api_key
      |> Ash.Changeset.for_update(:touch_last_used, %{})
      |> Ash.update()
    end

    if Application.get_env(:founder_pad, :async_touch_last_used, true) do
      Task.start(update)
    else
      update.()
    end
  end
end
