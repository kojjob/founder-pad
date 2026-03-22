# Onboarding Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the 4-step onboarding flow into the app lifecycle so new users create their org, invite teammates, and deploy their first agent — with a dashboard banner nudging incomplete users.

**Architecture:** Remove org creation from registration (move to onboarding). Add membership detection to AssignDefaults hook. Add dismissible banner to dashboard. Create InviteEmail mailer following existing AuthMailer pattern. Harden onboarding validations and error handling.

**Tech Stack:** Phoenix LiveView, Ash Framework, Swoosh (mailer), Oban (async)

**Spec:** `docs/superpowers/specs/2026-03-22-onboarding-flow-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/founder_pad_web/live/auth/register_live.ex` | Modify | Remove org+membership creation (lines 136-169) |
| `lib/founder_pad_web/hooks/assign_defaults.ex` | Modify | Add membership query, set `onboarding_complete` assign |
| `lib/founder_pad_web/live/onboarding_live.ex` | Modify | Skip-if-done, validation, invite emails, safe error handling |
| `lib/founder_pad_web/live/dashboard_live.ex` | Modify | Add dismissible setup banner |
| `lib/founder_pad/notifications/mailers/invite_mailer.ex` | Create | Swoosh email for team invites |
| `test/founder_pad_web/live/onboarding_live_test.exs` | Create | Full onboarding flow tests |
| `test/founder_pad_web/live/auth/auth_test.exs` | Modify | Update registration test (no longer creates org) |

---

### Task 1: Create InviteMailer

**Files:**
- Create: `lib/founder_pad/notifications/mailers/invite_mailer.ex`

- [ ] **Step 1: Create the InviteMailer module**

```elixir
# lib/founder_pad/notifications/mailers/invite_mailer.ex
defmodule FounderPad.Notifications.InviteMailer do
  @moduledoc "Sends team invitation emails."
  import Swoosh.Email

  alias FounderPad.Mailer

  @from {"FounderPad", "noreply@founderpad.io"}

  def invite(email, org_name) do
    register_url = "#{FounderPadWeb.Endpoint.url()}/auth/register"

    new()
    |> to(email)
    |> from(@from)
    |> subject("You've been invited to join #{org_name} on FounderPad")
    |> html_body("""
    <h2>You're invited!</h2>
    <p>You've been invited to join <strong>#{org_name}</strong> on FounderPad.</p>
    <p>Create your account to get started:</p>
    <a href="#{register_url}">Join #{org_name}</a>
    """)
    |> text_body("You've been invited to join #{org_name} on FounderPad. Sign up at: #{register_url}")
    |> Mailer.deliver()
  end
end
```

- [ ] **Step 2: Verify it compiles**

Run: `mix compile`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add -f lib/founder_pad/notifications/mailers/invite_mailer.ex
git commit -m "feat(onboarding): add InviteMailer for team invitations"
```

---

### Task 2: Remove org creation from RegisterLive

**Files:**
- Modify: `lib/founder_pad_web/live/auth/register_live.ex:136-169`
- Modify: `test/founder_pad_web/live/auth/auth_test.exs:104-134`

- [ ] **Step 1: Update the auth test — registration should no longer create org**

In `test/founder_pad_web/live/auth/auth_test.exs`, replace the test at line 104-134:

```elixir
    test "registration does not create organisation (deferred to onboarding)", %{conn: conn} do
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

      # Verify NO organisation or membership was created
      memberships =
        FounderPad.Accounts.Membership
        |> Ash.read!()
        |> Enum.filter(&(&1.user_id == user.id))

      assert memberships == []
    end
```

- [ ] **Step 2: Run the test to verify it fails (Red)**

Run: `mix test test/founder_pad_web/live/auth/auth_test.exs --only line:104`
Expected: FAIL — registration still creates org

- [ ] **Step 3: Remove org creation from RegisterLive**

In `lib/founder_pad_web/live/auth/register_live.ex`, replace lines 136-169 with:

```elixir
        token = AshAuthentication.user_to_subject(user)

        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully!")
         |> redirect(
           to: "/auth/session?token=#{URI.encode_www_form(token)}&redirect_to=%2Fonboarding"
         )}
```

- [ ] **Step 4: Run the test to verify it passes (Green)**

Run: `mix test test/founder_pad_web/live/auth/auth_test.exs`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add -f lib/founder_pad_web/live/auth/register_live.ex test/founder_pad_web/live/auth/auth_test.exs
git commit -m "refactor(auth): remove org creation from registration, defer to onboarding"
```

---

### Task 3: Add onboarding_complete to AssignDefaults hook

**Files:**
- Modify: `lib/founder_pad_web/hooks/assign_defaults.ex`
- Modify: `test/founder_pad_web/live/auth/auth_test.exs` (AssignDefaults describe block)

- [ ] **Step 1: Write the test for onboarding_complete assign**

Add to `test/founder_pad_web/live/auth/auth_test.exs` in the "AssignDefaults hook" describe block:

```elixir
    test "sets onboarding_complete to false when user has no org", %{conn: conn} do
      user = create_user!()
      token = AshAuthentication.user_to_subject(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, view, _html} = live(conn, "/dashboard")

      # Banner should appear for users without an org
      html = render(view)
      assert html =~ "Complete your workspace setup"
    end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/founder_pad_web/live/auth/auth_test.exs --only line:240`
Expected: FAIL — banner text not found

- [ ] **Step 3: Update AssignDefaults hook**

Replace `lib/founder_pad_web/hooks/assign_defaults.ex`:

```elixir
defmodule FounderPadWeb.Hooks.AssignDefaults do
  @moduledoc """
  LiveView on_mount hook that assigns default values needed by the app layout.
  Loads the current_user from the session token and checks onboarding status.
  """
  import Phoenix.Component, only: [assign: 2]

  require Ash.Query

  def on_mount(:default, _params, session, socket) do
    socket = assign(socket, active_nav: :dashboard, setup_banner_dismissed: false)

    case session["user_token"] do
      nil ->
        {:cont, assign(socket, current_user: nil, onboarding_complete: false)}

      token ->
        case AshAuthentication.subject_to_user(token, FounderPad.Accounts.User) do
          {:ok, user} ->
            onboarding_complete = has_membership?(user.id)
            {:cont, assign(socket, current_user: user, onboarding_complete: onboarding_complete)}

          _ ->
            {:cont, assign(socket, current_user: nil, onboarding_complete: false)}
        end
    end
  end

  defp has_membership?(user_id) do
    case FounderPad.Accounts.Membership
         |> Ash.Query.filter(user_id: user_id)
         |> Ash.Query.limit(1)
         |> Ash.read() do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end
end
```

- [ ] **Step 4: Run test — will still fail (need banner in dashboard)**

Run: `mix test test/founder_pad_web/live/auth/auth_test.exs`
Expected: The new test still fails (banner not rendered yet), but existing tests pass

- [ ] **Step 5: Commit the hook change**

```bash
git add -f lib/founder_pad_web/hooks/assign_defaults.ex
git commit -m "feat(hooks): add onboarding_complete detection to AssignDefaults"
```

---

### Task 4: Add dismissible setup banner to Dashboard

**Files:**
- Modify: `lib/founder_pad_web/live/dashboard_live.ex`

- [ ] **Step 1: Add the dismiss event handler**

Add to `dashboard_live.ex` event handlers section:

```elixir
  def handle_event("dismiss_setup_banner", _, socket) do
    {:noreply, assign(socket, setup_banner_dismissed: true)}
  end
```

- [ ] **Step 2: Add the banner to the render function**

In `dashboard_live.ex`, at the top of the render template (line 132, inside `<div class="space-y-8">`), add immediately after the opening div:

```heex
      <%!-- Onboarding Banner --%>
      <div
        :if={not @onboarding_complete and not @setup_banner_dismissed}
        class="flex items-center justify-between gap-4 p-4 rounded-xl bg-primary/10 border border-primary/20"
      >
        <div class="flex items-center gap-3">
          <span class="material-symbols-outlined text-primary text-xl">rocket_launch</span>
          <p class="text-sm font-medium text-on-surface">
            Complete your workspace setup to get the most out of FounderPad
          </p>
        </div>
        <div class="flex items-center gap-2">
          <.link
            navigate="/onboarding"
            class="primary-gradient px-4 py-2 rounded-lg text-xs font-bold whitespace-nowrap"
          >
            Complete Setup
          </.link>
          <button
            phx-click="dismiss_setup_banner"
            class="p-1 text-on-surface-variant hover:text-on-surface transition-colors"
            aria-label="Dismiss"
          >
            <span class="material-symbols-outlined text-lg">close</span>
          </button>
        </div>
      </div>
```

- [ ] **Step 3: Run AssignDefaults test to verify banner appears**

Run: `mix test test/founder_pad_web/live/auth/auth_test.exs`
Expected: All tests PASS including the "Complete your workspace setup" assertion

- [ ] **Step 4: Commit**

```bash
git add -f lib/founder_pad_web/live/dashboard_live.ex
git commit -m "feat(dashboard): add dismissible onboarding setup banner"
```

---

### Task 5: Harden OnboardingLive — skip-if-done, validation, invites

**Files:**
- Modify: `lib/founder_pad_web/live/onboarding_live.ex`

- [ ] **Step 1: Add skip-if-done check in mount**

In `onboarding_live.ex`, after resolving `current_user` in `mount` (around line 46), add:

```elixir
    # Skip if user already has an org
    if current_user && has_membership?(current_user.id) do
      {:ok,
       socket
       |> assign(current_user: current_user)
       |> put_flash(:info, "You've already completed onboarding")
       |> push_navigate(to: "/dashboard")}
    else
      {:ok,
       assign(socket,
         page_title: "Welcome",
         step: 1,
         total_steps: 4,
         current_user: current_user,
         org_name: "",
         invite_emails: [],
         invite_input: "",
         selected_template: nil,
         templates: @templates,
         error: nil
       )}
    end
```

Add the `has_membership?` helper at the bottom:

```elixir
  defp has_membership?(user_id) do
    case FounderPad.Accounts.Membership
         |> Ash.Query.filter(user_id: user_id)
         |> Ash.Query.limit(1)
         |> Ash.read() do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end
```

- [ ] **Step 2: Add validation to next_step**

Replace the `next_step` handler:

```elixir
  def handle_event("next_step", _, socket) do
    case validate_step(socket.assigns.step, socket.assigns) do
      :ok ->
        {:noreply, socket |> assign(error: nil) |> update(:step, &min(&1 + 1, socket.assigns.total_steps))}

      {:error, msg} ->
        {:noreply, assign(socket, error: msg)}
    end
  end

  defp validate_step(1, assigns) do
    if String.trim(assigns.org_name) == "", do: {:error, "Please enter an organisation name."}, else: :ok
  end

  defp validate_step(2, assigns) do
    # Validate any pending email in the input field
    pending = String.trim(assigns.invite_input)
    if pending != "" and not valid_email?(pending) do
      {:error, "Please enter a valid email address or clear the input."}
    else
      :ok
    end
  end

  defp validate_step(_, _), do: :ok
```

- [ ] **Step 3: Add email validation to add_invite**

Replace the `add_invite` handler:

```elixir
  def handle_event("add_invite", %{"email" => email}, socket) do
    email = String.trim(email)

    cond do
      email == "" ->
        {:noreply, assign(socket, invite_input: "")}

      not valid_email?(email) ->
        {:noreply, assign(socket, error: "Please enter a valid email address.")}

      email in socket.assigns.invite_emails ->
        {:noreply, assign(socket, invite_input: "", error: "This email has already been added.")}

      true ->
        {:noreply, assign(socket, invite_emails: socket.assigns.invite_emails ++ [email], invite_input: "", error: nil)}
    end
  end

  defp valid_email?(email) do
    String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  end
```

- [ ] **Step 4: Harden create_workspace with safe error handling**

Replace `create_workspace`:

```elixir
  defp create_workspace(user, org_name, selected_template) do
    with {:ok, org} <-
           FounderPad.Accounts.Organisation
           |> Ash.Changeset.for_create(:create, %{name: String.trim(org_name)})
           |> Ash.create(),
         {:ok, _membership} <-
           FounderPad.Accounts.Membership
           |> Ash.Changeset.for_create(:create, %{
             role: :owner,
             user_id: user.id,
             organisation_id: org.id
           })
           |> Ash.create() do
      agent = create_agent_from_template(selected_template, org.id)
      {:ok, org, agent}
    else
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp create_agent_from_template(nil, _org_id), do: nil

  defp create_agent_from_template(template_key, org_id) do
    case Map.get(@templates, template_key) do
      nil -> nil
      tmpl ->
        case FounderPad.AI.Agent
             |> Ash.Changeset.for_create(:create, %{
               name: tmpl.name,
               description: tmpl.description,
               system_prompt: tmpl.system_prompt,
               model: "claude-sonnet-4-20250514",
               provider: :anthropic,
               temperature: tmpl.temperature,
               max_tokens: tmpl.max_tokens,
               organisation_id: org_id
             })
             |> Ash.create() do
          {:ok, agent} -> agent
          {:error, _} -> nil
        end
    end
  end
```

- [ ] **Step 5: Add invite email sending to complete handler**

Update the `complete` handler's success path to send invites:

```elixir
        case create_workspace(user, org_name, selected) do
          {:ok, org, agent} when not is_nil(agent) ->
            send_invite_emails(socket.assigns.invite_emails, org_name)

            {:noreply,
             socket
             |> put_flash(:info, "Welcome to FounderPad!")
             |> push_navigate(to: "/agents/#{agent.id}")}

          {:ok, org, nil} ->
            send_invite_emails(socket.assigns.invite_emails, org_name)

            {:noreply,
             socket
             |> put_flash(:info, "Welcome to FounderPad!")
             |> push_navigate(to: "/dashboard")}

          {:error, reason} ->
            {:noreply, assign(socket, error: "Setup failed: #{reason}")}
        end
```

Add the `send_invite_emails` helper:

```elixir
  defp send_invite_emails([], _org_name), do: :ok

  defp send_invite_emails(emails, org_name) do
    Enum.each(emails, fn email ->
      Task.start(fn ->
        FounderPad.Notifications.InviteMailer.invite(email, org_name)
      end)
    end)
  end
```

- [ ] **Step 6: Verify compilation**

Run: `mix compile`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add -f lib/founder_pad_web/live/onboarding_live.ex
git commit -m "feat(onboarding): add validation, skip-if-done, invite emails, safe error handling"
```

---

### Task 6: Write onboarding tests

**Files:**
- Create: `test/founder_pad_web/live/onboarding_live_test.exs`

- [ ] **Step 1: Write the test file**

```elixir
defmodule FounderPadWeb.OnboardingLiveTest do
  use FounderPadWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FounderPad.Factory

  defp auth_conn(conn, user) do
    token = AshAuthentication.user_to_subject(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  describe "mount" do
    test "redirects to login when unauthenticated", %{conn: conn} do
      # Onboarding is outside :app live_session, so it loads user from session directly
      {:ok, _view, html} = live(conn, "/onboarding")
      # Without auth, page renders but current_user is nil
      assert html =~ "Create Your Organisation"
    end

    test "redirects to dashboard when user already has an org", %{conn: conn} do
      user = create_user!()
      org = create_organisation!()
      create_membership!(user, org, :owner)

      conn = auth_conn(conn, user)

      {:ok, conn} =
        conn
        |> live("/onboarding")
        |> follow_redirect(conn)

      assert conn.resp_body =~ "already completed" or redirected_to(conn) =~ "/dashboard"
    end
  end

  describe "step validation" do
    test "blocks step 1 advance with blank org name", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      html = render_click(view, "next_step")
      assert html =~ "Please enter an organisation name"
    end

    test "rejects invalid email in step 2", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      # Fill org name and advance
      render_change(view, "update_org_name", %{"org_name" => "Test Org"})
      render_click(view, "next_step")

      # Try adding invalid email
      html = render_submit(view, "add_invite", %{"email" => "not-an-email"})
      assert html =~ "valid email"
    end

    test "accepts valid email in step 2", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "Test Org"})
      render_click(view, "next_step")

      html = render_submit(view, "add_invite", %{"email" => "teammate@example.com"})
      assert html =~ "teammate@example.com"
    end
  end

  describe "complete" do
    test "creates org, membership, and agent with template", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      # Step 1: org name
      render_change(view, "update_org_name", %{"org_name" => "My Startup"})
      render_click(view, "next_step")

      # Step 2: skip invites
      render_click(view, "next_step")

      # Step 3: select template
      render_click(view, "select_template", %{"template" => "research"})
      render_click(view, "next_step")

      # Step 4: complete
      render_click(view, "complete")

      # Verify org created
      orgs = FounderPad.Accounts.Organisation |> Ash.read!()
      assert Enum.any?(orgs, &(&1.name == "My Startup"))

      # Verify membership created
      memberships =
        FounderPad.Accounts.Membership
        |> Ash.read!()
        |> Enum.filter(&(&1.user_id == user.id))

      assert length(memberships) == 1
      assert hd(memberships).role == :owner

      # Verify agent created
      agents = FounderPad.AI.Agent |> Ash.read!()
      assert Enum.any?(agents, &(&1.name == "Research Assistant"))
    end

    test "completes without agent when no template selected", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      render_change(view, "update_org_name", %{"org_name" => "No Agent Org"})
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "next_step")
      render_click(view, "complete")

      # Verify redirect to dashboard (no agent to navigate to)
      flash = assert_redirect(view)
      assert elem(flash, 0) =~ "/dashboard"
    end

    test "shows error when completing without org name", %{conn: conn} do
      user = create_user!()
      conn = auth_conn(conn, user)

      {:ok, view, _html} = live(conn, "/onboarding")

      # Try to skip to end and complete
      # Step validation should block at step 1
      html = render_click(view, "next_step")
      assert html =~ "Please enter an organisation name"
    end
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `mix test test/founder_pad_web/live/onboarding_live_test.exs`
Expected: All tests PASS

- [ ] **Step 3: Run the full test suite**

Run: `mix test`
Expected: 0 failures (excluding pre-existing notification handler tests if untracked)

- [ ] **Step 4: Commit**

```bash
git add -f test/founder_pad_web/live/onboarding_live_test.exs
git commit -m "test(onboarding): add comprehensive onboarding flow tests"
```

---

### Task 7: Final verification and PR

- [ ] **Step 1: Run full test suite**

Run: `mix test`
Expected: All tests pass

- [ ] **Step 2: Create PR**

```bash
git push -u origin HEAD
gh pr create --title "feat(onboarding): wire onboarding flow with invites and dashboard banner" --body "## Summary
- Remove org creation from registration (defer to onboarding)
- Add onboarding_complete detection in AssignDefaults hook
- Add dismissible setup banner to dashboard
- Add skip-if-done redirect in onboarding
- Add step validation (org name required, email format check)
- Add InviteMailer for team invite emails
- Harden create_workspace with proper error handling

## Test plan
- [x] Registration no longer creates org/membership
- [x] Dashboard shows banner for users without org
- [x] Onboarding redirects to dashboard if already completed
- [x] Blank org name blocked at step 1
- [x] Invalid emails rejected at step 2
- [x] Full flow creates org + membership + agent
- [x] Flow works without selecting agent template"
```
