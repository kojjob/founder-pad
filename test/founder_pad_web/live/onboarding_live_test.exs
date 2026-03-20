defmodule FounderPadWeb.OnboardingLiveTest do
  use FounderPadWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FounderPad.Factory

  defp setup_auth(conn) do
    user = create_user!()
    token = AshAuthentication.user_to_subject(user)

    conn =
      conn
      |> init_test_session(%{})
      |> put_session(:user_token, token)

    {conn, user}
  end

  describe "Onboarding step navigation" do
    test "renders first step", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/onboarding")
      assert html =~ "Create Your Organisation"
      assert html =~ "Step 1 of 4"
    end

    test "navigates through all steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")

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
      {:ok, view, _html} = live(conn, "/onboarding")
      render_click(view, "next_step")
      html = render_click(view, "prev_step")
      assert html =~ "Step 1 of 4"
    end
  end

  describe "Onboarding data capture" do
    test "org name persists across steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Acme Inc"})
      html = render_click(view, "next_step")
      # Go to step 4 to see summary
      render_click(view, "next_step")
      html = render_click(view, "next_step")
      assert html =~ "Acme Inc"
    end

    test "can select agent template", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")
      # Go to step 3
      render_click(view, "next_step")
      render_click(view, "next_step")

      html = render_click(view, "select_template", %{"template" => "research"})
      assert html =~ "border-primary"
    end

    test "can add invite emails", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")
      render_click(view, "next_step")

      html = render_submit(view, "add_invite", %{"email" => "alice@example.com"})
      assert html =~ "alice@example.com"
    end

    test "can remove invite emails", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")
      render_click(view, "next_step")

      render_submit(view, "add_invite", %{"email" => "alice@example.com"})
      html = render_click(view, "remove_invite", %{"email" => "alice@example.com"})
      refute html =~ "alice@example.com"
    end
  end

  describe "Onboarding completion (authenticated)" do
    test "creates organisation on complete", %{conn: conn} do
      {conn, user} = setup_auth(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Test Org Complete"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "complete")

      # Should redirect to dashboard (no agent selected)
      assert_redirect(view, "/dashboard")
    end

    test "creates org + agent when template selected", %{conn: conn} do
      {conn, user} = setup_auth(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Agent Org"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "select_template", %{"template" => "research"})
      render_click(view, "next_step")
      render_click(view, "complete")

      # Should redirect to the agent page
      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"/agents/"
    end

    test "shows error when org name is empty", %{conn: conn} do
      {conn, _user} = setup_auth(conn)
      {:ok, view, _html} = live(conn, "/onboarding")

      # Don't set org name, go to step 4 and complete
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "next_step")
      html = render_click(view, "complete")

      assert html =~ "organisation name"
    end
  end
end
