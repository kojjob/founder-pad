defmodule LinkHubWeb.BillingLiveTest do
  use LinkHubWeb.ConnCase, async: true
  use LinkHub.LiveViewHelpers

  alias LinkHub.Factory

  describe "billing page" do
    test "renders with current plan info", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      Factory.create_plan!(%{
        name: "Pro",
        slug: "pro",
        price_cents: 7900,
        sort_order: 1,
        max_agents: 25,
        max_seats: 10,
        max_api_calls_per_month: 50_000
      })

      {:ok, _view, html} = live(conn, ~p"/billing")

      assert html =~ "Billing"
      assert html =~ "Current Plan"
    end

    test "usage shows real counts from workspace data", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      Factory.create_plan!(%{
        name: "Pro",
        slug: "pro",
        price_cents: 7900,
        sort_order: 1,
        max_agents: 25,
        max_api_calls_per_month: 50_000
      })

      # Create 3 usage records for this org
      for _ <- 1..3 do
        LinkHub.Billing.UsageRecord
        |> Ash.Changeset.for_create(:create, %{
          event_type: "api_call",
          quantity: 1,
          workspace_id: org.id
        })
        |> Ash.create!()
      end

      # Create 2 agents
      Factory.create_agent!(org, %{name: "Agent A"})
      Factory.create_agent!(org, %{name: "Agent B"})

      {:ok, _view, html} = live(conn, ~p"/billing")

      # Usage should reflect 3 API calls and the plan limit of 50K
      assert html =~ "3 / 50K"
      # Token display: 3*500=1500 → format_number → "2K", 50000*500=25M
      assert html =~ "/ 25.0M"
    end

    test "invoice list shows invoices from database", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      Factory.create_plan!(%{name: "Starter", slug: "pro", price_cents: 2900, sort_order: 0})

      Factory.create_invoice!(org, %{
        invoice_number: "INV-2026-001",
        amount_cents: 7900,
        status: :paid,
        period_start: ~D[2026-03-01],
        period_end: ~D[2026-03-31]
      })

      Factory.create_invoice!(org, %{
        invoice_number: "INV-2026-002",
        amount_cents: 2900,
        status: :pending,
        period_start: ~D[2026-02-01],
        period_end: ~D[2026-02-28]
      })

      {:ok, _view, html} = live(conn, ~p"/billing")

      assert html =~ "INV-2026-001"
      assert html =~ "INV-2026-002"
      assert html =~ "$79.00"
      assert html =~ "$29.00"
      assert html =~ "Mar 01, 2026"
    end

    test "shows empty state when no invoices exist", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      Factory.create_plan!(%{name: "Starter", slug: "pro", price_cents: 2900, sort_order: 0})

      {:ok, _view, html} = live(conn, ~p"/billing")

      assert html =~ "No invoices yet"
    end
  end
end
