defmodule FounderPad.Billing.BillingIntegrationTest do
  @moduledoc "Integration tests covering the full billing lifecycle."
  use FounderPad.DataCase, async: true

  import FounderPad.Factory

  alias FounderPad.Billing
  alias FounderPad.Billing.{Invoice, Plan, Subscription, UsageRecord}
  alias FounderPad.Billing.UsageTracker

  require Ash.Query

  @moduletag :integration

  # ── Plan creation and retrieval ──────────────────────────────────────

  describe "plan creation and retrieval" do
    test "creates the four standard plans with correct attributes" do
      free =
        create_plan!(
          name: "Free",
          slug: "free",
          price_cents: 0,
          interval: :monthly,
          features: ["Basic support"],
          max_seats: 1,
          max_agents: 1,
          max_api_calls_per_month: 100,
          sort_order: 0
        )

      starter =
        create_plan!(
          name: "Starter",
          slug: "starter",
          price_cents: 1900,
          interval: :monthly,
          features: ["Email support", "5 agents"],
          max_seats: 3,
          max_agents: 5,
          max_api_calls_per_month: 5_000,
          sort_order: 1
        )

      pro =
        create_plan!(
          name: "Pro",
          slug: "pro",
          price_cents: 4900,
          interval: :monthly,
          features: ["Priority support", "Unlimited agents", "API access"],
          max_seats: 10,
          max_agents: 50,
          max_api_calls_per_month: 50_000,
          sort_order: 2
        )

      enterprise =
        create_plan!(
          name: "Enterprise",
          slug: "enterprise",
          price_cents: 14_900,
          interval: :monthly,
          features: ["Dedicated support", "Custom integrations", "SLA"],
          max_seats: 100,
          max_agents: 999,
          max_api_calls_per_month: 999_999,
          sort_order: 3
        )

      {:ok, plans} = Billing.list_plans()
      assert length(plans) == 4

      assert free.price_cents == 0
      assert starter.price_cents == 1_900
      assert pro.price_cents == 4_900
      assert enterprise.price_cents == 14_900
    end

    test "retrieves a plan by id" do
      plan = create_plan!(name: "Lookup Plan", slug: "lookup-plan")

      assert {:ok, found} = Billing.get_plan(plan.id)
      assert found.id == plan.id
      assert found.name == "Lookup Plan"
    end

    test "retrieves a plan by stripe product id" do
      plan = create_plan!(stripe_product_id: "prod_unique_abc")

      assert {:ok, found} = Billing.get_plan_by_stripe_id("prod_unique_abc")
      assert found.id == plan.id
    end

    test "plan defaults are applied correctly" do
      plan = create_plan!()

      assert plan.active == true
      assert plan.interval == :monthly
    end

    test "plans enforce unique slug identity" do
      create_plan!(slug: "duplicate-slug")

      assert {:error, _} =
               Plan
               |> Ash.Changeset.for_create(:create, %{
                 name: "Dup",
                 slug: "duplicate-slug",
                 stripe_product_id: "prod_dup_#{System.unique_integer([:positive])}",
                 stripe_price_id: "price_dup_#{System.unique_integer([:positive])}",
                 price_cents: 0
               })
               |> Ash.create()
    end
  end

  # ── Subscription lifecycle ───────────────────────────────────────────

  describe "subscription lifecycle" do
    setup do
      org = create_organisation!()
      plan = create_plan!(name: "Pro", slug: "pro-lifecycle")
      %{org: org, plan: plan}
    end

    test "create → active → cancel flow", %{org: org, plan: plan} do
      # 1. Create subscription (simulates checkout.session.completed)
      stripe_sub_id = "sub_lifecycle_#{System.unique_integer([:positive])}"
      stripe_cust_id = "cus_lifecycle_#{System.unique_integer([:positive])}"

      {:ok, subscription} =
        Subscription
        |> Ash.Changeset.for_create(:create, %{
          stripe_subscription_id: stripe_sub_id,
          stripe_customer_id: stripe_cust_id,
          status: :active,
          current_period_start: DateTime.utc_now(),
          current_period_end: DateTime.utc_now() |> DateTime.add(30, :day),
          organisation_id: org.id,
          plan_id: plan.id
        })
        |> Ash.create()

      assert subscription.status == :active
      assert subscription.organisation_id == org.id
      assert subscription.plan_id == plan.id
      assert subscription.cancel_at_period_end == false

      # 2. Verify it shows as the org's active subscription
      {:ok, active_subs} =
        Billing.get_active_subscription(%{organisation_id: org.id})

      assert length(active_subs) >= 1
      assert Enum.any?(active_subs, &(&1.id == subscription.id))

      # 3. Cancel the subscription
      {:ok, canceled} =
        subscription
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update()

      assert canceled.status == :canceled
      assert canceled.canceled_at != nil

      # 4. Verify no active subscriptions remain for the org
      {:ok, remaining} =
        Billing.get_active_subscription(%{organisation_id: org.id})

      refute Enum.any?(remaining, &(&1.id == subscription.id))
    end

    test "subscription transitions through update_from_stripe", %{org: org, plan: plan} do
      {:ok, subscription} =
        Subscription
        |> Ash.Changeset.for_create(:create, %{
          stripe_subscription_id: "sub_transition_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_transition_#{System.unique_integer([:positive])}",
          status: :active,
          organisation_id: org.id,
          plan_id: plan.id
        })
        |> Ash.create()

      # Simulate Stripe marking it past_due
      {:ok, updated} =
        subscription
        |> Ash.Changeset.for_update(:update_from_stripe, %{
          status: :past_due,
          cancel_at_period_end: true
        })
        |> Ash.update()

      assert updated.status == :past_due
      assert updated.cancel_at_period_end == true
    end

    test "trialing subscription appears as active for org lookup", %{org: org, plan: plan} do
      {:ok, subscription} =
        Subscription
        |> Ash.Changeset.for_create(:create, %{
          stripe_subscription_id: "sub_trial_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_trial_#{System.unique_integer([:positive])}",
          status: :trialing,
          trial_end: DateTime.utc_now() |> DateTime.add(14, :day),
          organisation_id: org.id,
          plan_id: plan.id
        })
        |> Ash.create()

      {:ok, active_subs} =
        Billing.get_active_subscription(%{organisation_id: org.id})

      assert Enum.any?(active_subs, &(&1.id == subscription.id))
    end

    test "enforces unique stripe_subscription_id", %{org: org, plan: plan} do
      stripe_sub_id = "sub_unique_#{System.unique_integer([:positive])}"

      {:ok, _} =
        Subscription
        |> Ash.Changeset.for_create(:create, %{
          stripe_subscription_id: stripe_sub_id,
          stripe_customer_id: "cus_a_#{System.unique_integer([:positive])}",
          status: :active,
          organisation_id: org.id,
          plan_id: plan.id
        })
        |> Ash.create()

      assert {:error, _} =
               Subscription
               |> Ash.Changeset.for_create(:create, %{
                 stripe_subscription_id: stripe_sub_id,
                 stripe_customer_id: "cus_b_#{System.unique_integer([:positive])}",
                 status: :active,
                 organisation_id: org.id,
                 plan_id: plan.id
               })
               |> Ash.create()
    end
  end

  # ── Usage tracking ──────────────────────────────────────────────────

  describe "usage tracking" do
    setup do
      org = create_organisation!()
      plan = create_plan!(max_api_calls_per_month: 5)

      {:ok, _sub} =
        Subscription
        |> Ash.Changeset.for_create(:create, %{
          stripe_subscription_id: "sub_usage_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_usage_#{System.unique_integer([:positive])}",
          status: :active,
          organisation_id: org.id,
          plan_id: plan.id
        })
        |> Ash.create()

      %{org: org, plan: plan}
    end

    test "records usage and associates it with the organisation", %{org: org} do
      {:ok, record} =
        UsageRecord
        |> Ash.Changeset.for_create(:create, %{
          event_type: "api_call",
          quantity: 1,
          metadata: %{"endpoint" => "/api/v1/agents"},
          organisation_id: org.id
        })
        |> Ash.create()

      assert record.event_type == "api_call"
      assert record.quantity == 1
      assert record.organisation_id == org.id
      assert record.metadata == %{"endpoint" => "/api/v1/agents"}
    end

    test "UsageTracker.track_api_call/1 creates a usage record", %{org: org} do
      assert {:ok, record} = UsageTracker.track_api_call(org.id)
      assert record.event_type == "api_call"
      assert record.quantity == 1
      assert record.organisation_id == org.id
    end

    test "UsageTracker.get_usage_count/2 returns correct count", %{org: org} do
      period_start = DateTime.utc_now() |> DateTime.add(-1, :hour)

      for _ <- 1..3 do
        UsageTracker.track_api_call(org.id)
      end

      assert UsageTracker.get_usage_count(org.id, period_start) == 3
    end

    test "UsageTracker.within_limits?/1 returns true when under limit", %{org: org} do
      assert UsageTracker.within_limits?(org.id) == true
    end

    test "UsageTracker.within_limits?/1 returns false when at limit", %{org: org} do
      # Plan has max_api_calls_per_month: 5
      for _ <- 1..5 do
        UsageTracker.track_api_call(org.id)
      end

      assert UsageTracker.within_limits?(org.id) == false
    end

    test "usage records can be listed by organisation", %{org: org} do
      other_org = create_organisation!()

      for _ <- 1..3 do
        UsageTracker.track_api_call(org.id)
      end

      UsageTracker.track_api_call(other_org.id)

      {:ok, all_records} = Billing.list_usage_records()

      org_records = Enum.filter(all_records, &(&1.organisation_id == org.id))
      other_records = Enum.filter(all_records, &(&1.organisation_id == other_org.id))

      assert length(org_records) == 3
      assert length(other_records) == 1
    end
  end

  # ── Invoice generation ──────────────────────────────────────────────

  describe "invoice generation" do
    setup do
      org = create_organisation!()
      plan = create_plan!(name: "Pro Invoice", slug: "pro-invoice", price_cents: 4_900)

      {:ok, sub} =
        Subscription
        |> Ash.Changeset.for_create(:create, %{
          stripe_subscription_id: "sub_inv_integ_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_inv_integ_#{System.unique_integer([:positive])}",
          status: :active,
          organisation_id: org.id,
          plan_id: plan.id
        })
        |> Ash.create()

      %{org: org, plan: plan, subscription: sub}
    end

    test "creates an invoice with correct amounts", %{org: org, plan: plan} do
      period_start = Date.utc_today() |> Date.beginning_of_month()
      period_end = Date.utc_today() |> Date.end_of_month()

      {:ok, invoice} =
        Invoice
        |> Ash.Changeset.for_create(:create, %{
          invoice_number: "INV-#{System.unique_integer([:positive])}",
          amount_cents: plan.price_cents,
          status: :paid,
          stripe_invoice_id: "inv_test_#{System.unique_integer([:positive])}",
          period_start: period_start,
          period_end: period_end,
          organisation_id: org.id
        })
        |> Ash.create()

      assert invoice.amount_cents == 4_900
      assert invoice.status == :paid
      assert invoice.period_start == period_start
      assert invoice.period_end == period_end
      assert invoice.organisation_id == org.id
    end

    test "invoices are created via StripeHandler on payment_succeeded", %{
      org: org,
      subscription: sub
    } do
      job_args = %{
        "type" => "invoice.payment_succeeded",
        "data" => %{
          "object" => %{
            "id" => "inv_integ_#{System.unique_integer([:positive])}",
            "number" => "INV-INTEG-001",
            "amount_paid" => 4_900,
            "subscription" => sub.stripe_subscription_id,
            "period_start" => DateTime.utc_now() |> DateTime.to_unix(),
            "period_end" => DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.to_unix()
          }
        }
      }

      assert :ok ==
               FounderPad.Billing.Workers.StripeHandler.perform(%Oban.Job{args: job_args})

      {:ok, invoices} = Billing.list_invoices()
      invoice = Enum.find(invoices, &(&1.invoice_number == "INV-INTEG-001"))
      assert invoice != nil
      assert invoice.amount_cents == 4_900
      assert invoice.status == :paid
      assert invoice.organisation_id == org.id
    end

    test "failed payment creates invoice with failed status", %{org: _org, subscription: sub} do
      job_args = %{
        "type" => "invoice.payment_failed",
        "data" => %{
          "object" => %{
            "id" => "inv_fail_integ_#{System.unique_integer([:positive])}",
            "number" => "INV-INTEG-FAIL-001",
            "amount_due" => 4_900,
            "subscription" => sub.stripe_subscription_id,
            "period_start" => DateTime.utc_now() |> DateTime.to_unix(),
            "period_end" => DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.to_unix()
          }
        }
      }

      assert :ok ==
               FounderPad.Billing.Workers.StripeHandler.perform(%Oban.Job{args: job_args})

      {:ok, invoices} = Billing.list_invoices()
      invoice = Enum.find(invoices, &(&1.invoice_number == "INV-INTEG-FAIL-001"))
      assert invoice != nil
      assert invoice.status == :failed
      assert invoice.amount_cents == 4_900
    end

    test "invoices can be listed", %{org: org} do
      for i <- 1..3 do
        create_invoice!(org,
          invoice_number: "INV-LIST-#{i}",
          amount_cents: i * 1_000,
          status: :paid
        )
      end

      {:ok, invoices} = Billing.list_invoices()
      org_invoices = Enum.filter(invoices, &(&1.organisation_id == org.id))
      assert length(org_invoices) == 3
    end

    test "invoice defaults to pending status" do
      org = create_organisation!()

      {:ok, invoice} =
        Invoice
        |> Ash.Changeset.for_create(:create, %{
          invoice_number: "INV-PENDING-#{System.unique_integer([:positive])}",
          amount_cents: 2_900,
          period_start: Date.utc_today() |> Date.beginning_of_month(),
          period_end: Date.utc_today() |> Date.end_of_month(),
          organisation_id: org.id
        })
        |> Ash.create()

      assert invoice.status == :pending
    end
  end
end
