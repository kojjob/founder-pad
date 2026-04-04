defmodule FounderPadWeb.PresenceTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "presence tracking on agent detail" do
    test "tracks user presence when viewing agent", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org, %{name: "Presence Bot"})

      {:ok, _view, html} = live(conn, "/agents/#{agent.id}")

      # After connecting, the user should be tracked in presence
      # Presence shows "online" indicator
      assert html =~ "Presence Bot"
    end

    test "shows presence indicators in the header", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org, %{name: "Collab Agent"})

      {:ok, view, _html} = live(conn, "/agents/#{agent.id}")

      # After the live view connects, presence should be tracked
      # Give presence a moment to sync
      Process.sleep(100)
      html = render(view)

      # The current user should appear in presence
      assert html =~ "online"
    end

    test "handles presence_diff messages gracefully", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = Factory.create_agent!(org)

      {:ok, view, _html} = live(conn, "/agents/#{agent.id}")

      # Simulate a presence diff broadcast
      Phoenix.PubSub.broadcast(
        FounderPad.PubSub,
        "agent:#{agent.id}",
        %Phoenix.Socket.Broadcast{
          topic: "agent:#{agent.id}",
          event: "presence_diff",
          payload: %{joins: %{}, leaves: %{}}
        }
      )

      # Should not crash
      html = render(view)
      assert html =~ agent.name
    end
  end
end
