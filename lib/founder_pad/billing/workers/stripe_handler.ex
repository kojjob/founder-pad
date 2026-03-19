defmodule FounderPad.Billing.Workers.StripeHandler do
  @moduledoc "Processes Stripe webhook events via Oban."
  use Oban.Worker, queue: :billing, max_attempts: 5

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => type, "data" => data}}) do
    case type do
      "customer.subscription.created" -> handle_subscription_created(data)
      "customer.subscription.updated" -> handle_subscription_updated(data)
      "customer.subscription.deleted" -> handle_subscription_deleted(data)
      "invoice.payment_succeeded" -> handle_payment_succeeded(data)
      "invoice.payment_failed" -> handle_payment_failed(data)
      _ ->
        Logger.info("Unhandled Stripe event: #{type}")
        :ok
    end
  end

  defp handle_subscription_created(%{"object" => sub}) do
    Logger.info("Stripe subscription created: #{sub["id"]}")
    :ok
  end

  defp handle_subscription_updated(%{"object" => sub}) do
    Logger.info("Stripe subscription updated: #{sub["id"]}")
    :ok
  end

  defp handle_subscription_deleted(%{"object" => sub}) do
    Logger.info("Stripe subscription deleted: #{sub["id"]}")
    :ok
  end

  defp handle_payment_succeeded(%{"object" => invoice}) do
    Logger.info("Payment succeeded for invoice: #{invoice["id"]}")
    :ok
  end

  defp handle_payment_failed(%{"object" => invoice}) do
    Logger.warning("Payment failed for invoice: #{invoice["id"]}")
    :ok
  end
end
