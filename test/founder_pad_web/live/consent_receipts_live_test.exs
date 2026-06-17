defmodule FounderPadWeb.ConsentReceiptsLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "consent receipts viewer" do
    test "lists the tenant's consent receipts", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      Factory.create_consent_receipt!(%{organisation: org, purpose: "merchant_onboarding"})

      {:ok, _view, html} = live(conn, ~p"/consent")

      assert html =~ "Consent"
      assert html =~ "merchant_onboarding"
    end

    test "does not show another tenant's consent receipts", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      other = Factory.create_organisation!()
      Factory.create_consent_receipt!(%{organisation: other, purpose: "secret_purpose"})

      {:ok, _view, html} = live(conn, ~p"/consent")
      refute html =~ "secret_purpose"
    end

    test "can withdraw a consent receipt", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      receipt = Factory.create_consent_receipt!(%{organisation: org})

      {:ok, view, _html} = live(conn, ~p"/consent")

      view
      |> element(~s|button[phx-click=withdraw][phx-value-id="#{receipt.id}"]|)
      |> render_click()

      reloaded = Ash.get!(FounderPad.Compliance.ConsentReceipt, receipt.id)
      assert reloaded.status == :withdrawn
    end
  end

  describe "verification summary on the verifications page" do
    test "shows a count of verifications by status", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      Factory.create_individual_verification!(%{organisation: org})

      {:ok, _view, html} = live(conn, ~p"/verifications")
      assert html =~ "Total"
    end
  end
end
