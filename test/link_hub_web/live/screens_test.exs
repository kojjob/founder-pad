defmodule LinkHubWeb.ScreensTest do
  use LinkHubWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  # ── Landing page ──────────────────────────────────────────────────

  describe "Landing page" do
    test "renders hero section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Ship Your SaaS"
      assert html =~ "Get Started Free"
      assert html =~ "primary-gradient"
    end

    test "renders pricing section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Free"
      assert html =~ "Starter"
      assert html =~ "Pro"
      assert html =~ "Enterprise"
    end

    test "renders features section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "AI Agent Orchestration"
      assert html =~ "Stripe Billing"
    end

    test "renders testimonials section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Loved by founders"
      assert html =~ "James Kowalski"
    end

    test "renders footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "LinkHub"
      assert html =~ "Privacy Policy"
      assert html =~ "Terms of Service"
    end
  end

  # ── Auth pages ────────────────────────────────────────────────────

  describe "Auth pages" do
    test "login page renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/login")
      assert html =~ "Welcome back"
      assert html =~ "Sign In"
      assert html =~ "Google"
      assert html =~ "GitHub"
    end

    test "login page has magic link option", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/login")
      assert html =~ "Magic Link"
    end

    test "login page links to register", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/login")
      assert html =~ "/auth/register"
      assert html =~ "Create one"
    end

    test "register page renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/register")
      assert html =~ "Create your account"
      assert html =~ "Create Account"
    end

    test "register page has OAuth buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/register")
      assert html =~ "Google"
      assert html =~ "GitHub"
    end

    test "register page links to login", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/register")
      assert html =~ "/auth/login"
      assert html =~ "Sign in"
    end
  end

  # ── App pages (auth-protected routes) ─────────────────────────────
  #
  # The RequireAuth hook redirects unauthenticated users to /auth/login
  # via push_navigate, which surfaces as {:error, {:live_redirect, ...}}.

  describe "App pages redirect unauthenticated users to login" do
    test "dashboard redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
    end

    test "agents redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/agents")
    end

    test "billing redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/billing")
    end

    test "team redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/team")
    end

    test "settings redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/settings")
    end

    test "activity redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/activity")
    end

    test "workspaces redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/workspaces")
    end
  end

  # ── Onboarding page ──────────────────────────────────────────────

  describe "Onboarding page" do
    test "renders first step", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/onboarding")
      assert html =~ "Create Your Workspace"
      assert html =~ "Step 1 of 4"
    end

    test "navigates through all steps", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")

      # Fill org name first (required)
      render_change(view, "update_org_name", %{"org_name" => "Test Org"})

      # Step 1 -> Step 2
      html = render_click(view, "next_step")
      assert html =~ "Step 2 of 4"
      assert html =~ "Invite Your Team"

      # Step 2 -> Step 3
      html = render_click(view, "next_step")
      assert html =~ "Step 3 of 4"
      assert html =~ "Create Your First Agent"

      # Step 3 -> Step 4
      html = render_click(view, "next_step")
      assert html =~ "Step 4 of 4"
    end

    test "step 4 shows completion message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")
      render_change(view, "update_org_name", %{"org_name" => "Test Org"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      html = render_click(view, "next_step")
      assert html =~ "All Set"
    end

    test "can go back to previous step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Test Org"})
      render_click(view, "next_step")
      html = render_click(view, "prev_step")
      assert html =~ "Step 1 of 4"
      assert html =~ "Create Your Workspace"
    end

    test "back button is not shown on step 1", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/onboarding")
      refute html =~ "prev_step"
    end

    test "complete event shows error when not authenticated", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")

      # Fill org name and navigate to step 4
      render_change(view, "update_org_name", %{"org_name" => "Test Org"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "next_step")

      # The "complete" event shows an error when not logged in
      html = render_click(view, "complete")
      assert html =~ "logged in"
    end

    test "cannot go past step 4 with next_step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Test Org"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "next_step")

      # Trying next_step at step 4 should stay at step 4
      html = render_click(view, "next_step")
      assert html =~ "Step 4 of 4"
    end

    test "cannot go before step 1", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/onboarding")

      # At step 1, prev_step should keep us at step 1
      html = render_click(view, "prev_step")
      assert html =~ "Step 1 of 4"
    end
  end

  # ── Sitemap ──────────────────────────────────────────────────────

  describe "Sitemap" do
    test "returns XML sitemap", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")
      assert response_content_type(conn, :xml)
      body = conn.resp_body
      assert body =~ "urlset"
      assert body =~ "<loc>"
    end

    test "includes key URLs", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")
      body = conn.resp_body
      assert body =~ "/auth/login"
      assert body =~ "/auth/register"
    end
  end
end
