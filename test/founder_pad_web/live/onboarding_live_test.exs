defmodule FounderPadWeb.OnboardingLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  import FounderPad.Factory

  defp setup_authenticated_conn(conn) do
    user = create_user!()

    token = AshAuthentication.user_to_subject(user)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, user}
  end

  describe "step navigation" do
    test "navigates through all steps", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, html} = live(conn, "/onboarding")

      assert html =~ "Create Your Organisation"
      assert html =~ "Step 1 of 4"

      html = render_click(view, "next_step")
      assert html =~ "Step 2 of 4"
      assert html =~ "Invite Your Team"

      html = render_click(view, "next_step")
      assert html =~ "Step 3 of 4"
      assert html =~ "Create Your First Agent"

      html = render_click(view, "next_step")
      assert html =~ "Step 4 of 4"
      assert html =~ "All Set"
    end

    test "can go back to previous step", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_click(view, "next_step")
      html = render_click(view, "prev_step")
      assert html =~ "Step 1 of 4"
    end
  end

  describe "step 1 - organisation name" do
    test "can enter org name and it persists between steps", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      # Enter org name
      render_change(view, "update_org_name", %{"org_name" => "Acme Corp"})

      # Navigate to step 2 and back - name should persist
      render_click(view, "next_step")
      html = render_click(view, "prev_step")
      assert html =~ "Acme Corp"
    end
  end

  describe "step 2 - invite team" do
    test "can add invite emails", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_click(view, "next_step")

      html = render_submit(view, "add_invite", %{"email" => "alice@example.com"})
      assert html =~ "alice@example.com"
    end

    test "can remove invite emails", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_click(view, "next_step")

      render_submit(view, "add_invite", %{"email" => "alice@example.com"})
      html = render_click(view, "remove_invite", %{"email" => "alice@example.com"})
      refute html =~ "alice@example.com"
    end
  end

  describe "step 3 - agent template selection" do
    test "can select agent template", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_click(view, "next_step")
      render_click(view, "next_step")

      html = render_click(view, "select_template", %{"template" => "research"})
      assert html =~ "border-primary"
    end
  end

  describe "step 4 - summary" do
    test "shows summary of what was configured", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Acme Corp"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "select_template", %{"template" => "research"})
      html = render_click(view, "next_step")

      assert html =~ "Acme Corp"
      assert html =~ "Research Assistant"
    end
  end

  describe "complete event" do
    test "creates organisation in DB", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Acme Corp"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "complete")

      require Ash.Query

      {:ok, orgs} =
        FounderPad.Accounts.Organisation
        |> Ash.Query.filter(name: "Acme Corp")
        |> Ash.read()

      assert length(orgs) == 1
      assert hd(orgs).name == "Acme Corp"
    end

    test "creates membership with :owner role", %{conn: conn} do
      {conn, user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Owner Test Org"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "complete")

      require Ash.Query

      {:ok, memberships} =
        FounderPad.Accounts.Membership
        |> Ash.Query.filter(user_id: user.id)
        |> Ash.read()

      assert length(memberships) == 1
      assert hd(memberships).role == :owner
    end

    test "creates agent if template selected", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Agent Test Org"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "select_template", %{"template" => "research"})
      render_click(view, "next_step")
      render_click(view, "complete")

      require Ash.Query

      {:ok, agents} =
        FounderPad.AI.Agent
        |> Ash.Query.filter(name: "Research Assistant")
        |> Ash.read()

      assert length(agents) == 1
    end

    test "redirects to agent page after completion with agent", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Redirect Test Org"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "select_template", %{"template" => "code_review"})
      render_click(view, "next_step")
      render_click(view, "complete")

      {path, _flash} = assert_redirect(view)
      assert path =~ "/agents/"
    end

    test "redirects to dashboard after completion without agent", %{conn: conn} do
      {conn, _user} = setup_authenticated_conn(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "No Agent Org"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "complete")

      assert_redirect(view, "/dashboard")
    end
  end
end
