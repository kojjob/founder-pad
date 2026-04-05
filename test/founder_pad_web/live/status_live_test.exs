defmodule FounderPadWeb.StatusLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.System.Incident
  import FounderPad.Factory

  describe "public status page" do
    test "renders status page with system components", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/status")

      assert html =~ "System Status"
      assert html =~ "API"
      assert html =~ "Dashboard"
      assert html =~ "AI Agents"
      assert html =~ "Billing"
      assert html =~ "Email"
      assert html =~ "Operational"
    end

    test "shows active incidents", %{conn: conn} do
      admin = create_admin_user!()

      Incident
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "API Latency Spike",
          severity: :major,
          status: :investigating,
          affected_components: ["API"]
        }, actor: admin)
      |> Ash.create!()

      {:ok, _view, html} = live(conn, ~p"/status")

      assert html =~ "API Latency Spike"
      assert html =~ "major"
    end

    test "shows recent incident history", %{conn: conn} do
      admin = create_admin_user!()

      # Create and resolve an incident
      incident =
        Incident
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Past Database Issue",
            severity: :minor
          }, actor: admin)
        |> Ash.create!()

      incident
      |> Ash.Changeset.for_update(:resolve, %{}, actor: admin)
      |> Ash.update!()

      {:ok, _view, html} = live(conn, ~p"/status")

      assert html =~ "Past Database Issue"
      assert html =~ "resolved"
    end

    test "shows all operational when no active incidents", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/status")

      assert html =~ "All Systems Operational"
    end
  end
end
