defmodule FounderPad.Notifications.PushSenderTest do
  use ExUnit.Case, async: true

  alias FounderPad.Notifications.PushSender

  describe "build_fcm_payload/2" do
    test "builds correct FCM payload" do
      notification = %{
        title: "New Message",
        body: "You have a new agent response",
        action_url: "/agents/123"
      }

      token = "fcm_device_token"

      payload = PushSender.build_fcm_payload(notification, token)

      assert payload["message"]["token"] == token
      assert payload["message"]["notification"]["title"] == "New Message"
      assert payload["message"]["notification"]["body"] == "You have a new agent response"
      assert payload["message"]["data"]["action_url"] == "/agents/123"
    end
  end

  describe "build_web_push_payload/1" do
    test "builds correct web push payload" do
      notification = %{
        title: "Team Invite",
        body: "You've been invited to join Acme",
        action_url: "/team"
      }

      payload = PushSender.build_web_push_payload(notification)

      decoded = Jason.decode!(payload)
      assert decoded["title"] == "Team Invite"
      assert decoded["body"] == "You've been invited to join Acme"
      assert decoded["data"]["url"] == "/team"
    end
  end
end
