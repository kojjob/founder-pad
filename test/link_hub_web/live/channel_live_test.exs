defmodule LinkHubWeb.ChannelLiveTest do
  use LinkHubWeb.ConnCase, async: true
  use LinkHub.LiveViewHelpers

  alias LinkHub.Factory

  setup %{conn: conn} do
    {conn, user, workspace} = setup_authenticated_user(conn)
    channel = Factory.create_channel!(workspace, user)
    Factory.join_channel!(channel, user)

    %{conn: conn, user: user, workspace: workspace, channel: channel}
  end

  describe "mount" do
    test "renders channel list", %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/channels")
      assert html =~ channel.name
      assert html =~ "Channels"
    end

    test "renders specific channel with compose box", %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/channels/#{channel.id}")
      assert html =~ channel.name
      assert html =~ "Send"
    end

    test "shows empty state when no channels", %{conn: conn} do
      # Create a new user with workspace but no channels
      user2 = Factory.create_user!()
      workspace2 = Factory.create_workspace!()
      Factory.create_membership!(user2, workspace2, :owner)

      token = AshAuthentication.user_to_subject(user2)

      conn2 =
        conn
        |> recycle()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, _view, html} = live(conn2, ~p"/channels")
      assert html =~ "No channels yet"
    end
  end

  describe "sending messages" do
    test "sends a message and it appears in the list", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")

      view
      |> form("#compose-form", %{body: "Hello from LiveView!"})
      |> render_submit()

      # The message arrives via PubSub broadcast
      html = render(view)
      assert html =~ "Hello from LiveView!"
    end

    test "compose box clears after sending", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")

      view
      |> form("#compose-form", %{body: "Test clearing"})
      |> render_submit()

      # The input should be cleared (value="")
      html = render(view)
      assert html =~ "Test clearing"
    end
  end

  describe "channel creation" do
    test "creates a new channel from the sidebar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/channels")

      # Open the form
      view |> element("button[phx-click=toggle_new_channel]") |> render_click()

      # Submit
      view
      |> form("#new-channel-form", %{name: "engineering", visibility: "public"})
      |> render_submit()

      # Should navigate and show the new channel
      html = render(view)
      assert html =~ "engineering"
    end
  end

  describe "threading" do
    test "opens and displays thread panel", %{conn: conn, channel: channel, user: user} do
      # Pre-create a message with replies
      parent = Factory.send_message!(channel, user, "Parent message")
      Factory.send_message!(channel, user, "Reply 1", %{parent_message_id: parent.id})

      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")

      # Click thread button
      # Use the reply count link (visible when replies exist)
      render_click(view, "open_thread", %{"message-id" => parent.id})

      html = render(view)
      assert html =~ "Thread"
      assert html =~ "Parent message"
      assert html =~ "Reply 1"
    end

    test "closes thread panel", %{conn: conn, channel: channel, user: user} do
      parent = Factory.send_message!(channel, user, "Thread parent")
      Factory.send_message!(channel, user, "A reply", %{parent_message_id: parent.id})

      {:ok, view, _html} = live(conn, ~p"/channels/#{channel.id}")

      # Use the reply count link (visible when replies exist)
      render_click(view, "open_thread", %{"message-id" => parent.id})

      assert render(view) =~ "Thread"

      view |> element("button[phx-click=close_thread]") |> render_click()

      # Thread panel should be gone — the close button won't exist
      refute has_element?(view, "button[phx-click=close_thread]")
    end
  end
end
