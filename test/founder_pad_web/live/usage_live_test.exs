defmodule FounderPadWeb.UsageLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "usage page" do
    test "renders usage dashboard with plan info", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/usage")

      assert html =~ "API Usage"
      assert html =~ "API Calls This Period"
      assert html =~ "Plan Limits"
    end

    test "shows usage count for the org", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      # Create some usage records
      for _ <- 1..5 do
        FounderPad.Billing.UsageRecord
        |> Ash.Changeset.for_create(:create, %{
          event_type: "api_call",
          quantity: 1,
          organisation_id: org.id
        })
        |> Ash.create!()
      end

      {:ok, _view, html} = live(conn, ~p"/usage")

      assert html =~ "5 /"
    end

    test "shows usage history table", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)

      FounderPad.Billing.UsageRecord
      |> Ash.Changeset.for_create(:create, %{
        event_type: "api_call",
        quantity: 1,
        organisation_id: org.id
      })
      |> Ash.create!()

      {:ok, _view, html} = live(conn, ~p"/usage")

      assert html =~ "Usage History"
      assert html =~ "api_call"
    end

    test "shows empty state when no usage records", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/usage")

      assert html =~ "No usage records yet"
    end
  end
end
