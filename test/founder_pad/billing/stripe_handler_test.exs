defmodule FounderPad.Billing.Workers.StripeHandlerTest do
  use FounderPad.DataCase, async: true

  import FounderPad.Factory

  alias FounderPad.Billing.Workers.StripeHandler

  describe "checkout.session.completed" do
    test "creates subscription for the organisation" do
      org = create_organisation!()
      plan = create_plan!()

      job_args = %{
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "subscription" => "sub_test_123",
            "customer" => "cus_test_456",
            "metadata" => %{
              "organisation_id" => org.id,
              "plan_id" => plan.id
            }
          }
        }
      }

      assert :ok == StripeHandler.perform(%Oban.Job{args: job_args})

      # Verify subscription was created
      {:ok, [subscription]} = FounderPad.Billing.list_subscriptions()
      assert subscription.stripe_subscription_id == "sub_test_123"
      assert subscription.stripe_customer_id == "cus_test_456"
      assert subscription.status == :active
      assert subscription.organisation_id == org.id
      assert subscription.plan_id == plan.id
    end
  end

  describe "customer.subscription.updated" do
    test "updates subscription status" do
      org = create_organisation!()
      plan = create_plan!()
      subscription = create_subscription!(org, plan, "sub_update_123", "cus_update_456")

      job_args = %{
        "type" => "customer.subscription.updated",
        "data" => %{
          "object" => %{
            "id" => "sub_update_123",
            "status" => "past_due",
            "current_period_start" => 1_700_000_000,
            "current_period_end" => 1_702_592_000,
            "cancel_at_period_end" => true
          }
        }
      }

      assert :ok == StripeHandler.perform(%Oban.Job{args: job_args})

      {:ok, updated} = Ash.get(FounderPad.Billing.Subscription, subscription.id)
      assert updated.status == :past_due
      assert updated.cancel_at_period_end == true
    end
  end

  describe "customer.subscription.deleted" do
    test "marks subscription as canceled" do
      org = create_organisation!()
      plan = create_plan!()
      subscription = create_subscription!(org, plan, "sub_delete_123", "cus_delete_456")

      job_args = %{
        "type" => "customer.subscription.deleted",
        "data" => %{
          "object" => %{
            "id" => "sub_delete_123"
          }
        }
      }

      assert :ok == StripeHandler.perform(%Oban.Job{args: job_args})

      {:ok, canceled} = Ash.get(FounderPad.Billing.Subscription, subscription.id)
      assert canceled.status == :canceled
      assert canceled.canceled_at != nil
    end
  end

  describe "invoice.payment_succeeded" do
    test "creates invoice with paid status" do
      org = create_organisation!()
      plan = create_plan!()
      _subscription = create_subscription!(org, plan, "sub_inv_123", "cus_inv_456")

      job_args = %{
        "type" => "invoice.payment_succeeded",
        "data" => %{
          "object" => %{
            "id" => "inv_success_123",
            "number" => "INV-0042",
            "amount_paid" => 2900,
            "subscription" => "sub_inv_123",
            "period_start" => 1_700_000_000,
            "period_end" => 1_702_592_000
          }
        }
      }

      assert :ok == StripeHandler.perform(%Oban.Job{args: job_args})

      {:ok, invoices} = FounderPad.Billing.list_invoices()
      invoice = Enum.find(invoices, &(&1.stripe_invoice_id == "inv_success_123"))
      assert invoice != nil
      assert invoice.status == :paid
      assert invoice.amount_cents == 2900
      assert invoice.organisation_id == org.id
    end
  end

  describe "invoice.payment_failed" do
    test "creates invoice with failed status" do
      org = create_organisation!()
      plan = create_plan!()
      _subscription = create_subscription!(org, plan, "sub_fail_123", "cus_fail_456")

      job_args = %{
        "type" => "invoice.payment_failed",
        "data" => %{
          "object" => %{
            "id" => "inv_fail_123",
            "number" => "INV-0043",
            "amount_due" => 2900,
            "subscription" => "sub_fail_123",
            "period_start" => 1_700_000_000,
            "period_end" => 1_702_592_000
          }
        }
      }

      assert :ok == StripeHandler.perform(%Oban.Job{args: job_args})

      {:ok, invoices} = FounderPad.Billing.list_invoices()
      invoice = Enum.find(invoices, &(&1.stripe_invoice_id == "inv_fail_123"))
      assert invoice != nil
      assert invoice.status == :failed
    end
  end

  # Helper to create a subscription for tests
  defp create_subscription!(org, plan, stripe_sub_id, stripe_cust_id) do
    FounderPad.Billing.Subscription
    |> Ash.Changeset.for_create(:create, %{
      stripe_subscription_id: stripe_sub_id,
      stripe_customer_id: stripe_cust_id,
      status: :active,
      organisation_id: org.id,
      plan_id: plan.id
    })
    |> Ash.create!()
  end
end
