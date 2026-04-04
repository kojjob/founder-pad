defmodule FounderPadWeb.Admin.IncidentsLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.System.Incident
  import FounderPad.Factory

  describe "admin incidents page" do
    test "admin can see incidents list", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      Incident
      |> Ash.Changeset.for_create(:create, %{
        title: "Test Incident",
        severity: :major
      }, actor: admin)
      |> Ash.create!()

      {:ok, _view, html} = live(conn, ~p"/admin/incidents")

      assert html =~ "Incidents"
      assert html =~ "Test Incident"
    end

    test "admin can create an incident", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, view, _html} = live(conn, ~p"/admin/incidents")

      view |> element("button", "New Incident") |> render_click()

      html =
        view
        |> form("#incident-form", %{
          "incident" => %{
            "title" => "New Outage",
            "description" => "Services are down",
            "severity" => "critical",
            "status" => "investigating"
          }
        })
        |> render_submit()

      assert html =~ "New Outage"
      assert html =~ "Incident created"
    end

    test "admin can resolve an incident", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      incident =
        Incident
        |> Ash.Changeset.for_create(:create, %{
          title: "Resolve Me",
          severity: :minor
        }, actor: admin)
        |> Ash.create!()

      {:ok, view, _html} = live(conn, ~p"/admin/incidents")

      html =
        view
        |> element(~s|button[phx-click=resolve][phx-value-id="#{incident.id}"]|)
        |> render_click()

      assert html =~ "resolved"
    end

    test "non-admin is redirected", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      assert {:error, {:live_redirect, _}} = live(conn, ~p"/admin/incidents")
    end
  end
end
