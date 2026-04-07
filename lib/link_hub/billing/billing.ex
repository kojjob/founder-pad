defmodule LinkHub.Billing do
  @moduledoc "Ash domain for plans, subscriptions, invoices, and usage tracking."
  use Ash.Domain

  resources do
    resource LinkHub.Billing.Plan do
      define(:list_plans, action: :read)
      define(:get_plan, action: :read, get_by: [:id])
      define(:get_plan_by_stripe_id, action: :read, get_by: [:stripe_product_id])
    end

    resource LinkHub.Billing.Subscription do
      define(:list_subscriptions, action: :read)
      define(:get_subscription, action: :read, get_by: [:id])
      define(:get_active_subscription, action: :by_workspace)
      define(:get_subscription_by_stripe_id, action: :by_stripe_id)
      define(:create_subscription, action: :create)
    end

    resource LinkHub.Billing.UsageRecord do
      define(:create_usage_record, action: :create)
      define(:list_usage_records, action: :read)
    end

    resource LinkHub.Billing.Invoice do
      define(:create_invoice, action: :create)
      define(:list_invoices, action: :read)
    end
  end
end
