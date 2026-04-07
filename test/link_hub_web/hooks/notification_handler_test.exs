defmodule LinkHubWeb.Hooks.NotificationHandlerTest do
  use LinkHubWeb.ConnCase, async: false
  use LinkHub.LiveViewHelpers

  import Phoenix.LiveViewTest

  alias LinkHub.Notifications

  describe "NotificationHandler hook" do
    setup %{conn: conn} do
      {conn, user, _org} = setup_authenticated_user(conn)
      {:ok, conn: conn, user: user}
    end

    test "loads unread notifications on mount", %{conn: conn, user: user} do
      {:ok, _notif} =
        Notifications.create_notification(%{
          type: :agent_completed,
          title: "Agent finished",
          body: "Your agent completed a run",
          user_id: user.id
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Badge should show count 1
      assert html =~ "data-notification-count"
      assert html =~ "Agent finished"
      assert html =~ "Your agent completed a run"
    end

    test "PubSub message adds notification to assigns", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Simulate a PubSub broadcast
      {:ok, notif} =
        Notifications.create_notification(%{
          type: :agent_completed,
          title: "New agent run",
          body: "Agent completed",
          user_id: user.id
        })

      Phoenix.PubSub.broadcast(
        LinkHub.PubSub,
        "user_notifications:#{user.id}",
        {:new_notification, notif}
      )

      # Allow time for the message to be processed
      :timer.sleep(100)

      html = render(view)
      assert html =~ "New agent run"
      assert html =~ "data-notification-count"
    end

    test "mark_all_read clears notifications", %{conn: conn, user: user} do
      {:ok, _notif} =
        Notifications.create_notification(%{
          type: :billing_warning,
          title: "Usage warning",
          body: "API usage at 80%",
          user_id: user.id
        })

      {:ok, view, html} = live(conn, ~p"/dashboard")
      assert html =~ "Usage warning"

      # Click "Clear all" button
      view |> element("[data-action='mark-all-read']") |> render_click()

      html = render(view)
      # Badge should be gone (count is 0)
      refute html =~ "data-notification-count"
      refute html =~ "Usage warning"
    end

    test "mark single notification read removes it from list", %{conn: conn, user: user} do
      {:ok, notif} =
        Notifications.create_notification(%{
          type: :team_invite,
          title: "Team invitation",
          body: "You were invited to join a team",
          user_id: user.id
        })

      {:ok, view, html} = live(conn, ~p"/dashboard")
      assert html =~ "Team invitation"

      # Click on the notification to mark it as read
      view
      |> element("[data-action='mark-read'][data-notification-id='#{notif.id}']")
      |> render_click()

      html = render(view)
      refute html =~ "Team invitation"
    end

    test "does not load notifications when no user", %{conn: _conn} do
      # Build an unauthenticated conn -- should redirect to login
      conn = Phoenix.ConnTest.build_conn()
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, ~p"/dashboard")
    end
  end
end
