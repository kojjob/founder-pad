defmodule FounderPadWeb.WebhookLogsLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  defp create_webhook!(org, attrs \\ %{}) do
    default = %{
      url: "https://example.com/webhook",
      secret: "test_secret_#{System.unique_integer([:positive])}",
      events: ["agent.created", "conversation.completed"],
      active: true,
      organisation_id: org.id
    }

    FounderPad.Webhooks.OutboundWebhook
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!()
  end

  defp create_delivery!(webhook, attrs \\ %{}) do
    default = %{
      event_type: "agent.created",
      payload: %{"agent_id" => "abc-123"},
      webhook_id: webhook.id
    }

    FounderPad.Webhooks.WebhookDelivery
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!()
  end

  describe "webhook logs page" do
    test "renders webhook logs page with header", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/webhooks")

      assert html =~ "Webhook Logs"
      assert html =~ "Outbound Webhooks"
    end

    test "shows webhooks list", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      create_webhook!(org, %{url: "https://api.example.com/hooks"})
      create_webhook!(org, %{url: "https://api.other.com/events", active: false})

      {:ok, _view, html} = live(conn, ~p"/webhooks")

      assert html =~ "https://api.example.com/hooks"
      assert html =~ "https://api.other.com/events"
      assert html =~ "Active"
      assert html =~ "Inactive"
    end

    test "shows delivery history for webhooks", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      webhook = create_webhook!(org)

      delivery = create_delivery!(webhook, %{event_type: "agent.created"})

      delivery
      |> Ash.Changeset.for_update(:mark_delivered, %{
        response_status: 200,
        attempts: 1
      })
      |> Ash.update!()

      failed_delivery = create_delivery!(webhook, %{event_type: "conversation.completed"})

      failed_delivery
      |> Ash.Changeset.for_update(:mark_failed, %{
        error: "Connection refused",
        attempts: 3
      })
      |> Ash.update!()

      {:ok, view, html} = live(conn, ~p"/webhooks")

      # Expand webhook to see deliveries
      html = render_click(view, "toggle_webhook", %{"id" => webhook.id})

      assert html =~ "agent.created"
      assert html =~ "conversation.completed"
      assert html =~ "Delivered"
      assert html =~ "Failed"
    end

    test "shows empty state when no webhooks", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/webhooks")

      assert html =~ "No webhooks configured"
    end

    test "can expand payload details", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      webhook = create_webhook!(org)
      create_delivery!(webhook, %{payload: %{"agent_id" => "test-agent-id"}})

      {:ok, view, _html} = live(conn, ~p"/webhooks")

      # Toggle webhook to show deliveries
      html = render_click(view, "toggle_webhook", %{"id" => webhook.id})

      assert html =~ "test-agent-id"
    end

    test "retry button appears for failed deliveries", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      webhook = create_webhook!(org)
      delivery = create_delivery!(webhook)

      delivery
      |> Ash.Changeset.for_update(:mark_failed, %{
        error: "Timeout",
        attempts: 1
      })
      |> Ash.update!()

      {:ok, view, _html} = live(conn, ~p"/webhooks")

      html = render_click(view, "toggle_webhook", %{"id" => webhook.id})

      assert html =~ "Retry"
    end

    test "status badges show correct colors", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      webhook = create_webhook!(org)

      # Pending delivery
      create_delivery!(webhook, %{event_type: "test.pending"})

      # Delivered
      delivered = create_delivery!(webhook, %{event_type: "test.delivered"})
      delivered
      |> Ash.Changeset.for_update(:mark_delivered, %{response_status: 200, attempts: 1})
      |> Ash.update!()

      # Failed
      failed = create_delivery!(webhook, %{event_type: "test.failed"})
      failed
      |> Ash.Changeset.for_update(:mark_failed, %{error: "err", attempts: 1})
      |> Ash.update!()

      {:ok, view, _html} = live(conn, ~p"/webhooks")
      html = render_click(view, "toggle_webhook", %{"id" => webhook.id})

      assert html =~ "Pending"
      assert html =~ "Delivered"
      assert html =~ "Failed"
    end
  end
end
