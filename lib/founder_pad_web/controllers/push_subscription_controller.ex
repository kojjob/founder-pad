defmodule FounderPadWeb.PushSubscriptionController do
  use FounderPadWeb, :controller

  def create(conn, %{"subscription" => subscription_json, "user_id" => user_id}) do
    case FounderPad.Notifications.PushSubscription
         |> Ash.Changeset.for_create(:create, %{
           type: :web_push,
           token: subscription_json,
           device_name: conn.params["device_name"] || "Browser",
           user_id: user_id
         })
         |> Ash.create() do
      {:ok, _sub} ->
        json(conn, %{status: "ok"})

      {:error, _} ->
        # Likely duplicate -- that's fine
        json(conn, %{status: "ok"})
    end
  end
end
