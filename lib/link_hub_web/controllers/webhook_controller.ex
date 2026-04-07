defmodule LinkHubWeb.WebhookController do
  @moduledoc "Inbound webhook controller for Stripe and other services."
  use LinkHubWeb, :controller

  alias LinkHub.Billing.Workers.StripeHandler

  require Logger

  def stripe(conn, _params) do
    with {:ok, raw_body} <- read_raw_body(conn),
         {:ok, event} <- verify_stripe_signature(conn, raw_body) do
      %{type: event["type"], data: event["data"]}
      |> StripeHandler.new()
      |> Oban.insert()

      conn
      |> put_status(200)
      |> json(%{received: true})
    else
      {:error, reason} ->
        Logger.warning("Stripe webhook error: #{inspect(reason)}")

        conn
        |> put_status(400)
        |> json(%{error: "Invalid webhook"})
    end
  end

  defp read_raw_body(conn) do
    case conn.assigns[:raw_body] do
      nil -> {:error, :no_raw_body}
      body -> {:ok, body}
    end
  end

  defp verify_stripe_signature(conn, raw_body) do
    signing_secret = Application.get_env(:stripity_stripe, :signing_secret)

    case Plug.Conn.get_req_header(conn, "stripe-signature") do
      [signature] when is_binary(signing_secret) and signing_secret != "" ->
        Stripe.Webhook.construct_event(raw_body, signature, signing_secret)

      _ when is_binary(signing_secret) ->
        {:error, :missing_stripe_signature_header}

      _ ->
        if Application.get_env(:link_hub, :env) == :prod do
          Logger.error("Stripe signing secret not configured in production")
          {:error, :missing_signing_secret}
        else
          # Dev/test only: parse without verification
          {:ok, Jason.decode!(raw_body)}
        end
    end
  end
end
