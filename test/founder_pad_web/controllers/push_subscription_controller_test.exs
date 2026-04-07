defmodule FounderPadWeb.PushSubscriptionControllerTest do
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  describe "POST /api/push/subscribe" do
    test "creates a web push subscription", %{conn: conn} do
      user = create_user!()

      subscription_json =
        Jason.encode!(%{
          endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
          keys: %{p256dh: "test_p256dh_key", auth: "test_auth_key"}
        })

      conn =
        post(conn, "/api/push/subscribe", %{
          subscription: subscription_json,
          user_id: user.id,
          device_name: "Chrome/120"
        })

      assert json_response(conn, 200) == %{"status" => "ok"}

      # Verify subscription was persisted
      [sub] =
        FounderPad.Notifications.PushSubscription
        |> Ash.Query.for_read(:active_for_user, %{user_id: user.id})
        |> Ash.read!()

      assert sub.type == :web_push
      assert sub.token == subscription_json
      assert sub.device_name == "Chrome/120"
    end

    test "handles duplicate subscription gracefully", %{conn: conn} do
      user = create_user!()

      subscription_json =
        Jason.encode!(%{
          endpoint: "https://fcm.googleapis.com/fcm/send/abc123",
          keys: %{p256dh: "test_key", auth: "test_auth"}
        })

      # Create first subscription
      post(conn, "/api/push/subscribe", %{
        subscription: subscription_json,
        user_id: user.id,
        device_name: "Chrome"
      })

      # Second subscription with same token should not error
      conn =
        post(conn, "/api/push/subscribe", %{
          subscription: subscription_json,
          user_id: user.id,
          device_name: "Chrome"
        })

      assert json_response(conn, 200) == %{"status" => "ok"}
    end
  end
end
