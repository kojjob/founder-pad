defmodule FounderPadWeb.Admin.SubscriptionsLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "admin subscriptions list" do
    test "admin can see subscriptions page", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, _view, html} = live(conn, ~p"/admin/subscriptions")

      assert html =~ "Subscriptions"
    end

    test "admin can see subscription with org and plan", %{conn: conn} do
      {conn, _admin, org} = setup_authenticated_admin(conn)
      plan = Factory.create_plan!(%{name: "Pro Plan"})

      FounderPad.Billing.Subscription
      |> Ash.Changeset.for_create(:create, %{
        stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
        stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
        status: :active,
        organisation_id: org.id,
        plan_id: plan.id
      })
      |> Ash.create!()

      {:ok, _view, html} = live(conn, ~p"/admin/subscriptions")

      assert html =~ org.name
      assert html =~ "Pro Plan"
      assert html =~ "Active"
    end

    test "non-admin is redirected", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      assert {:error, {:live_redirect, _}} = live(conn, ~p"/admin/subscriptions")
    end
  end
end
