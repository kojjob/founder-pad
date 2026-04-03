defmodule FounderPadWeb.AuditLogLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  defp create_audit_log!(attrs \\ %{}) do
    default = %{
      action: :create,
      resource_type: "Agent",
      resource_id: Ash.UUID.generate(),
      actor_id: Ash.UUID.generate(),
      organisation_id: Ash.UUID.generate(),
      changes: %{"name" => "Test Agent"},
      metadata: %{"source" => "api"},
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0"
    }

    FounderPad.Audit.AuditLog
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!()
  end

  describe "audit log page" do
    test "renders audit log page with header", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "Audit Log"
      assert html =~ "Filter"
    end

    test "shows audit log entries", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      create_audit_log!(%{action: :create, resource_type: "Agent"})
      create_audit_log!(%{action: :login, resource_type: "Session"})

      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "Agent"
      assert html =~ "Session"
      assert html =~ "create"
      assert html =~ "login"
    end

    test "filters by action type", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      create_audit_log!(%{action: :create, resource_type: "Agent"})
      create_audit_log!(%{action: :login, resource_type: "Session"})
      create_audit_log!(%{action: :delete, resource_type: "User"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      html = render_click(view, "filter", %{"action" => "login"})

      assert html =~ "login"
      assert html =~ "Session"
      # The filtered view should not show the delete audit entry in the log list
      # We check for the specific resource_type in log entries context
      refute html =~ ">User<"
    end

    test "filters by resource type", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      create_audit_log!(%{action: :create, resource_type: "Agent"})
      create_audit_log!(%{action: :create, resource_type: "User"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      html = render_click(view, "filter_resource", %{"resource_type" => "Agent"})

      assert html =~ "Agent"
      refute html =~ ">User<"
    end

    test "search by text in resource type", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      create_audit_log!(%{action: :create, resource_type: "Agent", ip_address: "10.0.0.1"})
      create_audit_log!(%{action: :update, resource_type: "Subscription", ip_address: "10.0.0.2"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      html = render_click(view, "search", %{"query" => "Agent"})

      assert html =~ "Agent"
      # The search should exclude entries with resource_type "Subscription"
      # Check that the Subscription log entry's IP doesn't appear (specific to that entry)
      refute html =~ "10.0.0.2"
    end

    test "shows expandable changes and metadata", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      create_audit_log!(%{
        action: :update,
        resource_type: "Agent",
        changes: %{"name" => "Updated Agent"},
        metadata: %{"reason" => "user request"}
      })

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      # Get the log entry to expand
      logs =
        FounderPad.Audit.AuditLog
        |> Ash.read!()

      log = List.first(logs)

      html = render_click(view, "toggle_details", %{"id" => log.id})

      assert html =~ "Updated Agent"
      assert html =~ "user request"
    end

    test "shows empty state when no logs", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "No audit logs found"
    end

    test "clears filters", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      create_audit_log!(%{action: :create, resource_type: "Agent"})
      create_audit_log!(%{action: :login, resource_type: "Session"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      # Apply filter first
      render_click(view, "filter", %{"action" => "login"})

      # Clear filters
      html = render_click(view, "clear_filters", %{})

      assert html =~ "Agent"
      assert html =~ "Session"
    end

    test "export button is present", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      create_audit_log!(%{action: :create, resource_type: "Agent"})

      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "Export CSV"
    end

    test "shows IP address and user agent info", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      create_audit_log!(%{
        action: :login,
        resource_type: "Session",
        ip_address: "203.0.113.50",
        user_agent: "Mozilla/5.0"
      })

      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "203.0.113.50"
    end
  end
end
