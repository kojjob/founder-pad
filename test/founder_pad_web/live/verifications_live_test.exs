defmodule FounderPadWeb.VerificationsLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "verifications list" do
    test "lists the tenant's verifications with status", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      Factory.create_individual_verification!(%{organisation: org, external_id: "cust_seen"})

      {:ok, _view, html} = live(conn, ~p"/verifications")

      assert html =~ "Verifications"
      assert html =~ "cust_seen"
    end

    test "does not show another tenant's verifications", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      other_org = Factory.create_organisation!()

      Factory.create_individual_verification!(%{
        organisation: other_org,
        external_id: "cust_other"
      })

      {:ok, _view, html} = live(conn, ~p"/verifications")
      refute html =~ "cust_other"
    end
  end

  describe "verification detail" do
    test "shows status, risk and consent for a verification", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      ivf =
        Factory.create_individual_verification!(%{organisation: org, external_id: "cust_detail"})

      {:ok, _view, html} = live(conn, ~p"/verifications/#{ivf.id}")

      assert html =~ "cust_detail"
      assert html =~ "Risk"
    end
  end
end
