defmodule FounderPadWeb.CheckoutControllerTest do
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  test "redirects to simulated checkout for valid plan", %{conn: conn} do
    plan = create_plan!(slug: "test-checkout-plan")
    conn = post(conn, "/checkout/#{plan.slug}")
    assert redirected_to(conn) =~ "/billing"
  end

  test "redirects to billing with error for invalid plan", %{conn: conn} do
    conn = post(conn, "/checkout/nonexistent-plan")
    assert redirected_to(conn) == "/billing"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Unable to start checkout"
  end
end
