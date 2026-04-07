defmodule FounderPad.Notifications.PushSubscriptionTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  describe "create push subscription" do
    test "creates FCM subscription" do
      user = create_user!()

      {:ok, sub} =
        FounderPad.Notifications.PushSubscription
        |> Ash.Changeset.for_create(:create, %{
          type: :fcm,
          token: "fcm_device_token_123",
          device_name: "iPhone 15",
          user_id: user.id
        })
        |> Ash.create()

      assert sub.type == :fcm
      assert sub.token == "fcm_device_token_123"
      assert sub.active == true
    end

    test "creates web push subscription" do
      user = create_user!()

      {:ok, sub} =
        FounderPad.Notifications.PushSubscription
        |> Ash.Changeset.for_create(:create, %{
          type: :web_push,
          token:
            Jason.encode!(%{
              endpoint: "https://push.example.com",
              keys: %{p256dh: "key1", auth: "key2"}
            }),
          device_name: "Chrome Browser",
          user_id: user.id
        })
        |> Ash.create()

      assert sub.type == :web_push
    end

    test "enforces unique user + token" do
      user = create_user!()

      FounderPad.Notifications.PushSubscription
      |> Ash.Changeset.for_create(:create, %{type: :fcm, token: "same_token", user_id: user.id})
      |> Ash.create!()

      assert {:error, _} =
               FounderPad.Notifications.PushSubscription
               |> Ash.Changeset.for_create(:create, %{
                 type: :fcm,
                 token: "same_token",
                 user_id: user.id
               })
               |> Ash.create()
    end
  end

  describe "active_for_user" do
    test "returns only active subscriptions" do
      user = create_user!()

      sub1 =
        FounderPad.Notifications.PushSubscription
        |> Ash.Changeset.for_create(:create, %{type: :fcm, token: "token1", user_id: user.id})
        |> Ash.create!()

      sub2 =
        FounderPad.Notifications.PushSubscription
        |> Ash.Changeset.for_create(:create, %{
          type: :web_push,
          token: "token2",
          user_id: user.id
        })
        |> Ash.create!()

      # Deactivate one
      sub1 |> Ash.Changeset.for_update(:deactivate, %{}) |> Ash.update!()

      active =
        FounderPad.Notifications.PushSubscription
        |> Ash.Query.for_read(:active_for_user, %{user_id: user.id})
        |> Ash.read!()

      assert length(active) == 1
      assert hd(active).id == sub2.id
    end
  end
end
