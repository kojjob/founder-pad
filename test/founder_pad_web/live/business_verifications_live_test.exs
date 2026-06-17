defmodule FounderPadWeb.BusinessVerificationsLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "business verifications list" do
    test "lists the tenant's KYB checks", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      Factory.create_business_verification!(%{
        organisation: org,
        registered_name: "Acme Ghana Ltd"
      })

      {:ok, _view, html} = live(conn, ~p"/business-verifications")

      assert html =~ "Business Verifications"
      assert html =~ "Acme Ghana Ltd"
    end

    test "does not show another tenant's KYB checks", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      other = Factory.create_organisation!()
      Factory.create_business_verification!(%{organisation: other, registered_name: "Secret Co"})

      {:ok, _view, html} = live(conn, ~p"/business-verifications")
      refute html =~ "Secret Co"
    end
  end

  describe "review queue surfaces KYB cases" do
    test "a business_verification review case appears in the queue", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      Factory.create_review_case!(%{organisation: org, subject_type: :business_verification})

      {:ok, _view, html} = live(conn, ~p"/reviews")
      assert html =~ "business_verification"
    end
  end
end
