defmodule FounderPad.Billing do
  use Ash.Domain

  resources do
    resource FounderPad.Billing.Plan do
      define :list_plans, action: :read
      define :get_plan, action: :read, get_by: [:id]
      define :get_plan_by_stripe_id, action: :read, get_by: [:stripe_product_id]
    end

    resource FounderPad.Billing.Subscription do
      define :list_subscriptions, action: :read
      define :get_subscription, action: :read, get_by: [:id]
      define :get_active_subscription, action: :by_organisation
      define :get_subscription_by_stripe_id, action: :by_stripe_id
      define :create_subscription, action: :create
    end

    resource FounderPad.Billing.UsageRecord do
      define :create_usage_record, action: :create
      define :list_usage_records, action: :read
    end

    resource FounderPad.Billing.Invoice do
      define :create_invoice, action: :create
      define :list_invoices, action: :read
    end
  end
end
