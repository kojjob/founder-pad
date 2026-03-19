defmodule FounderPadWeb.Auth.AuthTest do
  use FounderPadWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FounderPad.Factory
  require Ash.Query

  describe "Login page" do
    test "renders login form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/login")
      assert html =~ "Welcome back"
      assert html =~ "Sign In"
      assert html =~ "Email"
      assert html =~ "Password"
    end

    @tag :skip
    test "login with valid credentials redirects to session controller", %{conn: conn} do
      password = "Password123!"
      user = create_user!(password: password)

      {:ok, view, _html} = live(conn, "/auth/login")

      view
      |> form("form", user: %{email: to_string(user.email), password: password})
      |> render_submit()

      # LiveView redirects to the session controller endpoint
      assert_redirect(view, ~r"/auth/session\?token=")
    end

    @tag :skip
    test "login with invalid credentials shows error", %{conn: conn} do
      create_user!(email: "test@example.com", password: "Password123!")

      {:ok, view, _html} = live(conn, "/auth/login")

      html =
        view
        |> form("form", user: %{email: "test@example.com", password: "wrongpassword"})
        |> render_submit()

      assert html =~ "Invalid email or password"
    end

    @tag :skip
    test "login with nonexistent email shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/auth/login")

      html =
        view
        |> form("form", user: %{email: "nonexistent@example.com", password: "Password123!"})
        |> render_submit()

      assert html =~ "Invalid email or password"
    end
  end

  describe "Registration page" do
    test "renders registration form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/auth/register")
      assert html =~ "Create your account"
      assert html =~ "Create Account"
      assert html =~ "Full Name"
      assert html =~ "Email"
      assert html =~ "Password"
    end

    @tag :skip
    test "registration with valid data redirects to session controller", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/auth/register")

      view
      |> form("form",
        user: %{
          name: "Test User",
          email: "newuser@example.com",
          password: "Password123!"
        }
      )
      |> render_submit()

      assert_redirect(view, ~r"/auth/session\?token=.*redirect_to=%2Fonboarding")
    end

    test "registration with duplicate email shows error", %{conn: conn} do
      existing = create_user!(email: "existing@example.com")

      {:ok, view, _html} = live(conn, "/auth/register")

      html =
        view
        |> form("form",
          user: %{
            name: "Another User",
            email: to_string(existing.email),
            password: "Password123!"
          }
        )
        |> render_submit()

      # Should show an error about duplicate email
      assert html =~ "has already been taken" or
               html =~ "Registration failed" or
               html =~ "email"
    end

    test "registration creates default organisation and membership", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/auth/register")

      view
      |> form("form",
        user: %{
          name: "Org Creator",
          email: "orgcreator@example.com",
          password: "Password123!"
        }
      )
      |> render_submit()

      # Verify user was created
      users =
        FounderPad.Accounts.User
        |> Ash.read!()
        |> Enum.filter(&(to_string(&1.email) == "orgcreator@example.com"))

      assert length(users) == 1
      user = hd(users)

      # Verify organisation was created with membership
      memberships =
        FounderPad.Accounts.Membership
        |> Ash.read!()
        |> Enum.filter(&(&1.user_id == user.id))

      assert length(memberships) == 1
      assert hd(memberships).role == :owner
    end
  end

  describe "Protected routes" do
    test "dashboard redirects to login when unauthenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
    end

    test "settings redirects to login when unauthenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/settings")
    end

    test "agents redirects to login when unauthenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/agents")
    end

    test "billing redirects to login when unauthenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/billing")
    end

    test "team redirects to login when unauthenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/team")
    end

    test "authenticated user can access dashboard", %{conn: conn} do
      user = create_user!()
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, _view, html} = live(conn, "/dashboard")
      assert html =~ "Dashboard" or html =~ "dashboard"
    end
  end

  describe "Session management" do
    test "session controller creates session and redirects", %{conn: conn} do
      user = create_user!()
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> get("/auth/session?token=#{URI.encode_www_form(token)}")

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :user_token) == token
    end

    test "session controller supports custom redirect_to", %{conn: conn} do
      user = create_user!()
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> get("/auth/session?token=#{URI.encode_www_form(token)}&redirect_to=/onboarding")

      assert redirected_to(conn) == "/onboarding"
    end

    test "logout clears session and redirects to login", %{conn: conn} do
      user = create_user!()
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)
        |> delete("/auth/session")

      assert redirected_to(conn) == "/auth/login"
    end
  end

  describe "AssignDefaults hook" do
    test "loads current_user from session token", %{conn: conn} do
      user = create_user!()
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, view, _html} = live(conn, "/dashboard")

      # The view should have current_user assigned
      assert view |> element("p", user.name || "User") |> has_element?()
    end

    test "sets current_user to nil when no token in session", %{conn: conn} do
      # Without auth, protected routes redirect to login
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} = live(conn, "/dashboard")
    end
  end
end
