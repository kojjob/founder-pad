defmodule FounderPadWeb.CheckoutController do
  use FounderPadWeb, :controller
  require Logger

  def create(conn, %{"plan_slug" => plan_slug}) do
    require Ash.Query

    with {:ok, plan} <- FounderPad.Billing.Plan
                        |> Ash.Query.filter(slug: plan_slug, active: true)
                        |> Ash.read_one(),
         true <- not is_nil(plan),
         {:ok, session} <- create_checkout_session(plan, conn) do
      redirect(conn, external: session.url)
    else
      _ ->
        conn
        |> put_flash(:error, "Unable to start checkout. Please try again.")
        |> redirect(to: "/billing")
    end
  end

  defp create_checkout_session(plan, _conn) do
    case Application.get_env(:stripity_stripe, :api_key) do
      nil ->
        Logger.info("Stripe not configured — simulating checkout for plan: #{plan.slug}")
        {:ok, %{url: "/billing?checkout=simulated&plan=#{plan.slug}"}}

      _key ->
        params = %{
          mode: "subscription",
          success_url: FounderPadWeb.Endpoint.url() <> "/billing?success=true",
          cancel_url: FounderPadWeb.Endpoint.url() <> "/billing?canceled=true",
          line_items: [%{price: plan.stripe_price_id, quantity: 1}]
        }

        Stripe.Checkout.Session.create(params)
    end
  end
end
