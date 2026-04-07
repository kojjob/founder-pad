# Admin Panel & API Key Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a super-admin panel for managing users, orgs, subscriptions, and feature flags, plus an API key management system with hashed storage and per-key rate limiting.

**Architecture:** Extend the existing admin live_session (RequireAdmin hook) with new LiveViews for user/org/subscription/feature-flag management. Create a new `FounderPad.ApiKeys` Ash domain with ApiKey and ApiKeyUsage resources. Add an ApiKeyAuth plug for API authentication. Add `suspended_at` to User for suspension, and impersonation via session tokens.

**Tech Stack:** Ash Framework 3.x, Phoenix LiveView 1.0, Hammer (rate limiting), Oban (background jobs), PostgreSQL

---

## File Structure

### New Files

```
lib/founder_pad/api_keys/
  api_keys.ex                                # Ash Domain
  resources/
    api_key.ex                               # API key resource (hashed storage)
    api_key_usage.ex                         # Per-key usage tracking

lib/founder_pad_web/live/admin/
  admin_dashboard_live.ex                    # /admin — system overview
  users_live.ex                              # /admin/users — user list + search
  user_detail_live.ex                        # /admin/users/:id — detail + actions
  organisations_live.ex                      # /admin/organisations — org list
  subscriptions_live.ex                      # /admin/subscriptions — sub management
  feature_flags_live.ex                      # /admin/feature-flags — toggle flags

lib/founder_pad_web/live/
  api_keys_live.ex                           # /api-keys — user-facing key management

lib/founder_pad_web/plugs/
  api_key_auth.ex                            # API key authentication plug

test/founder_pad/api_keys/
  api_key_test.exs

test/founder_pad_web/live/admin/
  users_live_test.exs
  feature_flags_live_test.exs

test/founder_pad_web/live/
  api_keys_live_test.exs

test/founder_pad_web/plugs/
  api_key_auth_test.exs

priv/repo/migrations/
  YYYYMMDD_add_suspended_at_to_users.exs
  YYYYMMDD_create_api_keys.exs
```

### Modified Files

```
lib/founder_pad/accounts/resources/user.ex      # Add suspended_at, suspend/unsuspend actions
lib/founder_pad/accounts/accounts.ex            # Add domain functions
lib/founder_pad_web/router.ex                   # Add admin + API key routes
lib/founder_pad_web/hooks/assign_defaults.ex    # Add impersonation detection
lib/founder_pad_web/components/layouts/app.html.heex  # Expand admin nav, impersonation banner
config/config.exs                               # Register ApiKeys domain
test/support/factory.ex                         # Add API key factories
test/support/live_view_helpers.ex               # Add admin setup helper
```

---

## Task 1: Add `suspended_at` to User + Suspend/Unsuspend Actions

**Files:**
- Modify: `lib/founder_pad/accounts/resources/user.ex`
- Modify: `lib/founder_pad/accounts/accounts.ex`
- Create: migration via `mix ash.codegen`
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Add suspended_at attribute to User**

In `lib/founder_pad/accounts/resources/user.ex`, add inside `attributes do` after `is_admin`:

```elixir
attribute :suspended_at, :utc_datetime_usec do
  public? true
end
```

- [ ] **Step 2: Add suspend and unsuspend actions**

In `lib/founder_pad/accounts/resources/user.ex`, add inside `actions do`:

```elixir
update :suspend do
  accept []
  change set_attribute(:suspended_at, &DateTime.utc_now/0)
end

update :unsuspend do
  accept []
  change set_attribute(:suspended_at, nil)
end

read :list_all do
  prepare build(sort: [inserted_at: :desc])
end
```

Add policy for these actions inside `policies do`:

```elixir
policy action([:suspend, :unsuspend, :list_all]) do
  authorize_if expr(^actor(:is_admin) == true)
end
```

- [ ] **Step 3: Add domain functions**

In `lib/founder_pad/accounts/accounts.ex`, add inside the User resource block:

```elixir
define :suspend_user, action: :suspend
define :unsuspend_user, action: :unsuspend
define :list_all_users, action: :list_all
```

- [ ] **Step 4: Generate and run migration**

```bash
mix ash.codegen add_suspended_at_to_users
mix ecto.migrate
MIX_ENV=test mix ecto.migrate
```

- [ ] **Step 5: Verify**

```bash
mix test
```

- [ ] **Step 6: Commit**

```bash
git add -f lib/founder_pad/accounts/ priv/repo/migrations/*suspended* config/
git commit -m "feat(accounts): add suspended_at to User with suspend/unsuspend actions"
```

---

## Task 2: ApiKeys Domain + Resources

**Files:**
- Create: `lib/founder_pad/api_keys/api_keys.ex`
- Create: `lib/founder_pad/api_keys/resources/api_key.ex`
- Create: `lib/founder_pad/api_keys/resources/api_key_usage.ex`
- Modify: `config/config.exs`

- [ ] **Step 1: Create ApiKey resource**

Create `lib/founder_pad/api_keys/resources/api_key.ex`:

```elixir
defmodule FounderPad.ApiKeys.ApiKey do
  use Ash.Resource,
    domain: FounderPad.ApiKeys,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "api_keys"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :key_prefix, :string do
      allow_nil? false
      public? true
    end

    attribute :key_hash, :string do
      allow_nil? false
    end

    attribute :scopes, {:array, :atom} do
      constraints items: [one_of: [:read, :write, :admin]]
      default [:read]
      allow_nil? false
      public? true
    end

    attribute :last_used_at, :utc_datetime_usec do
      public? true
    end

    attribute :expires_at, :utc_datetime_usec do
      public? true
    end

    attribute :revoked_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_key_hash, [:key_hash]
    identity :unique_prefix, [:key_prefix]
  end

  relationships do
    belongs_to :organisation, FounderPad.Accounts.Organisation do
      allow_nil? false
      attribute_type :uuid
    end

    belongs_to :created_by, FounderPad.Accounts.User do
      allow_nil? false
      attribute_type :uuid
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :scopes, :expires_at, :organisation_id, :created_by_id]

      change fn changeset, _context ->
        raw_key = generate_raw_key()
        prefix = "fp_" <> String.slice(raw_key, 0, 8)
        hash = :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)

        changeset
        |> Ash.Changeset.force_change_attribute(:key_prefix, prefix)
        |> Ash.Changeset.force_change_attribute(:key_hash, hash)
        |> Ash.Changeset.after_action(fn _changeset, key ->
          {:ok, Map.put(key, :__raw_key__, raw_key)}
        end)
      end
    end

    update :revoke do
      accept []
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end

    update :touch_last_used do
      accept []
      change set_attribute(:last_used_at, &DateTime.utc_now/0)
    end

    read :active do
      filter expr(is_nil(revoked_at) and (is_nil(expires_at) or expires_at > now()))
    end

    read :by_organisation do
      argument :organisation_id, :uuid, allow_nil?: false
      filter expr(organisation_id == ^arg(:organisation_id))
      prepare build(sort: [inserted_at: :desc])
    end

    read :by_key_hash do
      argument :hash, :string, allow_nil?: false
      filter expr(key_hash == ^arg(:hash) and is_nil(revoked_at))
    end
  end

  policies do
    policy action(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if always()
    end
  end

  defp generate_raw_key do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
```

- [ ] **Step 2: Create ApiKeyUsage resource**

Create `lib/founder_pad/api_keys/resources/api_key_usage.ex`:

```elixir
defmodule FounderPad.ApiKeys.ApiKeyUsage do
  use Ash.Resource,
    domain: FounderPad.ApiKeys,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "api_key_usage"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :endpoint, :string do
      public? true
    end

    attribute :method, :string do
      public? true
    end

    attribute :status_code, :integer do
      public? true
    end

    attribute :response_time_ms, :integer do
      public? true
    end

    attribute :ip_address, :string do
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :api_key, FounderPad.ApiKeys.ApiKey do
      allow_nil? false
      attribute_type :uuid
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:endpoint, :method, :status_code, :response_time_ms, :ip_address, :api_key_id]
    end

    read :by_key do
      argument :api_key_id, :uuid, allow_nil?: false
      filter expr(api_key_id == ^arg(:api_key_id))
      prepare build(sort: [inserted_at: :desc])
    end
  end
end
```

- [ ] **Step 3: Create ApiKeys domain module**

Create `lib/founder_pad/api_keys/api_keys.ex`:

```elixir
defmodule FounderPad.ApiKeys do
  use Ash.Domain

  resources do
    resource FounderPad.ApiKeys.ApiKey do
      define :create_api_key, action: :create
      define :revoke_api_key, action: :revoke
      define :touch_api_key_last_used, action: :touch_last_used
      define :list_active_keys, action: :active
      define :list_keys_by_organisation, action: :by_organisation, args: [:organisation_id]
      define :find_key_by_hash, action: :by_key_hash, args: [:hash]
    end

    resource FounderPad.ApiKeys.ApiKeyUsage do
      define :create_usage, action: :create
      define :list_usage_by_key, action: :by_key, args: [:api_key_id]
    end
  end
end
```

- [ ] **Step 4: Register domain in config**

In `config/config.exs`, add `FounderPad.ApiKeys` to `ash_domains`:

```elixir
FounderPad.ApiKeys
```

- [ ] **Step 5: Generate and run migration**

```bash
mix ash.codegen create_api_keys
mix ecto.migrate
MIX_ENV=test mix ecto.migrate
```

- [ ] **Step 6: Verify and commit**

```bash
mix compile
mix test
git add -f lib/founder_pad/api_keys/ config/config.exs priv/repo/migrations/*api_key*
git commit -m "feat(api-keys): add ApiKeys domain with ApiKey and ApiKeyUsage resources"
```

---

## Task 3: ApiKey Tests + Factories

**Files:**
- Create: `test/founder_pad/api_keys/api_key_test.exs`
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Add API key factory**

In `test/support/factory.ex`, add:

```elixir
def create_api_key!(org, user, attrs \\ %{}) do
  FounderPad.ApiKeys.ApiKey
  |> Ash.Changeset.for_create(:create, %{
    name: Map.get(attrs, :name, "Test Key #{System.unique_integer([:positive])}"),
    scopes: Map.get(attrs, :scopes, [:read]),
    organisation_id: org.id,
    created_by_id: user.id
  })
  |> Ash.create!()
end
```

- [ ] **Step 2: Write API key tests**

Create `test/founder_pad/api_keys/api_key_test.exs`:

```elixir
defmodule FounderPad.ApiKeys.ApiKeyTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  describe "create API key" do
    test "generates key with prefix and hash" do
      {_conn, user, org} = setup_user_with_org()

      {:ok, key} =
        FounderPad.ApiKeys.ApiKey
        |> Ash.Changeset.for_create(:create, %{
          name: "My API Key",
          scopes: [:read, :write],
          organisation_id: org.id,
          created_by_id: user.id
        })
        |> Ash.create()

      assert key.key_prefix =~ ~r/^fp_/
      assert key.key_hash
      assert key.scopes == [:read, :write]
      assert key.__raw_key__
    end

    test "raw key is only available on create" do
      {_conn, user, org} = setup_user_with_org()
      key = create_api_key!(org, user)

      reloaded = Ash.get!(FounderPad.ApiKeys.ApiKey, key.id)
      refute Map.has_key?(reloaded, :__raw_key__)
    end
  end

  describe "revoke API key" do
    test "sets revoked_at timestamp" do
      {_conn, user, org} = setup_user_with_org()
      key = create_api_key!(org, user)

      assert is_nil(key.revoked_at)

      {:ok, revoked} =
        key
        |> Ash.Changeset.for_update(:revoke, %{})
        |> Ash.update()

      assert revoked.revoked_at
    end
  end

  describe "find by hash" do
    test "finds active key by hash" do
      {_conn, user, org} = setup_user_with_org()
      key = create_api_key!(org, user)

      found =
        FounderPad.ApiKeys.ApiKey
        |> Ash.Query.for_read(:by_key_hash, %{hash: key.key_hash})
        |> Ash.read!()

      assert length(found) == 1
      assert hd(found).id == key.id
    end
  end

  defp setup_user_with_org do
    user = create_user!()
    org = create_organisation!()
    create_membership!(user, org, :owner)
    {nil, user, org}
  end
end
```

- [ ] **Step 3: Run tests and commit**

```bash
mix test test/founder_pad/api_keys/
git add -f test/founder_pad/api_keys/ test/support/factory.ex
git commit -m "test(api-keys): add API key tests and factory"
```

---

## Task 4: ApiKeyAuth Plug

**Files:**
- Create: `lib/founder_pad_web/plugs/api_key_auth.ex`
- Create: `test/founder_pad_web/plugs/api_key_auth_test.exs`

- [ ] **Step 1: Create the plug**

Create `lib/founder_pad_web/plugs/api_key_auth.ex`:

```elixir
defmodule FounderPadWeb.Plugs.ApiKeyAuth do
  @moduledoc "Authenticates API requests via API key in Authorization header."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         true <- String.starts_with?(token, "fp_") or not String.starts_with?(token, "fp_"),
         hash <- :crypto.hash(:sha256, token) |> Base.encode16(case: :lower),
         [api_key] <-
           FounderPad.ApiKeys.ApiKey
           |> Ash.Query.for_read(:by_key_hash, %{hash: hash})
           |> Ash.Query.load([:organisation])
           |> Ash.read!() do
      # Touch last_used_at asynchronously
      Task.start(fn ->
        api_key
        |> Ash.Changeset.for_update(:touch_last_used, %{})
        |> Ash.update()
      end)

      conn
      |> assign(:api_key, api_key)
      |> assign(:current_organisation, api_key.organisation)
    else
      _ -> conn
    end
  end
end
```

- [ ] **Step 2: Write plug test**

Create `test/founder_pad_web/plugs/api_key_auth_test.exs`:

```elixir
defmodule FounderPadWeb.Plugs.ApiKeyAuthTest do
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  alias FounderPadWeb.Plugs.ApiKeyAuth

  describe "call/2" do
    test "authenticates with valid API key" do
      user = create_user!()
      org = create_organisation!()
      create_membership!(user, org, :owner)
      key = create_api_key!(org, user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{key.__raw_key__}")
        |> ApiKeyAuth.call([])

      assert conn.assigns[:api_key]
      assert conn.assigns[:current_organisation].id == org.id
    end

    test "does nothing with no auth header" do
      conn =
        build_conn()
        |> ApiKeyAuth.call([])

      refute conn.assigns[:api_key]
    end

    test "does nothing with invalid key" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid_key_here")
        |> ApiKeyAuth.call([])

      refute conn.assigns[:api_key]
    end
  end
end
```

- [ ] **Step 3: Run tests and commit**

```bash
mix test test/founder_pad_web/plugs/api_key_auth_test.exs
git add -f lib/founder_pad_web/plugs/api_key_auth.ex test/founder_pad_web/plugs/api_key_auth_test.exs
git commit -m "feat(api-keys): add ApiKeyAuth plug for API authentication"
```

---

## Task 5: Admin Routes + Dashboard

**Files:**
- Modify: `lib/founder_pad_web/router.ex`
- Create: `lib/founder_pad_web/live/admin/admin_dashboard_live.ex`

- [ ] **Step 1: Add admin routes**

In `lib/founder_pad_web/router.ex`, add to the existing `:admin` live_session scope:

```elixir
live "/", AdminDashboardLive
live "/users", UsersLive
live "/users/:id", UserDetailLive
live "/organisations", OrganisationsLive
live "/subscriptions", SubscriptionsLive
live "/feature-flags", FeatureFlagsLive
```

Add user-facing API keys route to the `:app` live_session:

```elixir
live "/api-keys", ApiKeysLive
```

Add ApiKeyAuth plug to the `:api` pipeline:

```elixir
pipeline :api do
  plug :accepts, ["json"]
  plug FounderPadWeb.Plugs.ApiKeyAuth
  plug FounderPadWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
end
```

- [ ] **Step 2: Create AdminDashboardLive**

Create `lib/founder_pad_web/live/admin/admin_dashboard_live.ex`:

```elixir
defmodule FounderPadWeb.Admin.AdminDashboardLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    admin = socket.assigns.current_user

    user_count = FounderPad.Accounts.User |> Ash.Query.for_read(:list_all, actor: admin) |> Ash.read!() |> length()
    org_count = FounderPad.Accounts.Organisation |> Ash.read!() |> length()

    active_keys =
      FounderPad.ApiKeys.ApiKey
      |> Ash.Query.for_read(:active)
      |> Ash.read!()
      |> length()

    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       active_nav: :admin_dashboard,
       user_count: user_count,
       org_count: org_count,
       active_key_count: active_keys
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h1 class="font-heading text-2xl font-bold text-on-surface">Admin Dashboard</h1>
        <p class="text-on-surface-variant mt-1">System overview and management.</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <a href="/admin/users" class="bg-white rounded-2xl border border-neutral-200/60 p-6 hover:shadow-md transition-shadow">
          <p class="text-sm text-on-surface-variant mb-1">Total Users</p>
          <p class="text-3xl font-heading font-bold text-on-surface">{@user_count}</p>
        </a>
        <a href="/admin/organisations" class="bg-white rounded-2xl border border-neutral-200/60 p-6 hover:shadow-md transition-shadow">
          <p class="text-sm text-on-surface-variant mb-1">Organisations</p>
          <p class="text-3xl font-heading font-bold text-on-surface">{@org_count}</p>
        </a>
        <div class="bg-white rounded-2xl border border-neutral-200/60 p-6">
          <p class="text-sm text-on-surface-variant mb-1">Active API Keys</p>
          <p class="text-3xl font-heading font-bold text-on-surface">{@active_key_count}</p>
        </div>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 3: Commit**

```bash
git add -f lib/founder_pad_web/router.ex lib/founder_pad_web/live/admin/admin_dashboard_live.ex
git commit -m "feat(admin): add admin routes and dashboard overview"
```

---

## Task 6: Admin Users LiveView

**Files:**
- Create: `lib/founder_pad_web/live/admin/users_live.ex`
- Create: `lib/founder_pad_web/live/admin/user_detail_live.ex`
- Create: `test/founder_pad_web/live/admin/users_live_test.exs`

- [ ] **Step 1: Create UsersLive**

Admin user list with search, role/status filters, suspend/unsuspend actions. Table showing email, name, role (admin badge), status (active/suspended), created date, actions.

- [ ] **Step 2: Create UserDetailLive**

User detail page showing profile info, memberships, recent activity. Action buttons: suspend/unsuspend, toggle admin, impersonate. Impersonation stores `impersonated_user_id` in session and redirects to `/dashboard`.

- [ ] **Step 3: Write tests**

Test admin access, user listing, suspend/unsuspend flow, non-admin redirect.

- [ ] **Step 4: Commit**

```bash
git add -f lib/founder_pad_web/live/admin/users_live.ex lib/founder_pad_web/live/admin/user_detail_live.ex test/founder_pad_web/live/admin/users_live_test.exs
git commit -m "feat(admin): add user management LiveViews (list, detail, suspend)"
```

---

## Task 7: Admin Organisations + Subscriptions LiveViews

**Files:**
- Create: `lib/founder_pad_web/live/admin/organisations_live.ex`
- Create: `lib/founder_pad_web/live/admin/subscriptions_live.ex`

- [ ] **Step 1: Create OrganisationsLive**

Admin org list showing name, slug, member count, subscription status. Links to user detail for members.

- [ ] **Step 2: Create SubscriptionsLive**

Subscription list showing org name, plan, status, period dates. Action to cancel subscription.

- [ ] **Step 3: Commit**

```bash
git add -f lib/founder_pad_web/live/admin/organisations_live.ex lib/founder_pad_web/live/admin/subscriptions_live.ex
git commit -m "feat(admin): add organisation and subscription management LiveViews"
```

---

## Task 8: Admin Feature Flags LiveView

**Files:**
- Create: `lib/founder_pad_web/live/admin/feature_flags_live.ex`
- Create: `test/founder_pad_web/live/admin/feature_flags_live_test.exs`

- [ ] **Step 1: Create FeatureFlagsLive**

List all feature flags with toggle switches. Shows: key, name, description, enabled status, required_plan. Toggle sends `toggle` event to flip the flag via the existing `:toggle` action. Inline edit for required_plan.

- [ ] **Step 2: Write tests**

Test flag listing, toggle behavior.

- [ ] **Step 3: Commit**

```bash
git add -f lib/founder_pad_web/live/admin/feature_flags_live.ex test/founder_pad_web/live/admin/feature_flags_live_test.exs
git commit -m "feat(admin): add feature flags management LiveView"
```

---

## Task 9: User-Facing API Keys LiveView

**Files:**
- Create: `lib/founder_pad_web/live/api_keys_live.ex`
- Create: `test/founder_pad_web/live/api_keys_live_test.exs`

- [ ] **Step 1: Create ApiKeysLive**

User-facing page at `/api-keys` (inside app live_session). Shows org's API keys: name, prefix, scopes, created date, last used, status. Actions: create new key (shows raw key once in modal), revoke. Create form accepts name and scope checkboxes.

- [ ] **Step 2: Write tests**

Test key creation (raw key displayed), key listing, revocation.

- [ ] **Step 3: Commit**

```bash
git add -f lib/founder_pad_web/live/api_keys_live.ex test/founder_pad_web/live/api_keys_live_test.exs
git commit -m "feat(api-keys): add user-facing API key management LiveView"
```

---

## Task 10: Impersonation + Admin Nav + Final Integration

**Files:**
- Modify: `lib/founder_pad_web/hooks/assign_defaults.ex`
- Modify: `lib/founder_pad_web/components/layouts/app.html.heex`
- Modify: `test/support/live_view_helpers.ex`

- [ ] **Step 1: Add impersonation detection to AssignDefaults**

In `lib/founder_pad_web/hooks/assign_defaults.ex`, add impersonation check in `on_mount/4`:

After loading `current_user`, check session for `impersonated_user_id`:
```elixir
case session["impersonated_user_id"] do
  nil ->
    {:cont, assign(socket, impersonating: false, admin_user: nil)}
  impersonated_id ->
    case Ash.get(FounderPad.Accounts.User, impersonated_id) do
      {:ok, imp_user} ->
        {:cont, assign(socket,
          admin_user: user,
          current_user: imp_user,
          impersonating: true
        )}
      _ ->
        {:cont, assign(socket, impersonating: false, admin_user: nil)}
    end
end
```

- [ ] **Step 2: Add impersonation banner to app layout**

In `app.html.heex`, add at the very top of the main content area (before flash):

```heex
<div :if={assigns[:impersonating]} class="bg-amber-500 text-white px-4 py-2 flex items-center justify-between text-sm">
  <span>
    <span class="font-semibold">Impersonating:</span>
    {@current_user.name || @current_user.email}
  </span>
  <a href="/admin/stop-impersonation" class="underline hover:no-underline font-medium">
    End Impersonation
  </a>
</div>
```

- [ ] **Step 3: Expand admin nav links**

In `app.html.heex`, update the admin nav section to include new links:

```heex
<.nav_link href="/admin" icon="admin_panel_settings" label="Dashboard" active={@active_nav == :admin_dashboard} />
<.nav_link href="/admin/users" icon="group" label="Users" active={@active_nav == :admin_users} />
<.nav_link href="/admin/organisations" icon="corporate_fare" label="Orgs" active={@active_nav == :admin_orgs} />
<.nav_link href="/admin/feature-flags" icon="toggle_on" label="Flags" active={@active_nav == :admin_flags} />
```

Keep existing Blog, Changelog, SEO links.

- [ ] **Step 4: Add API Keys nav link in app section**

Add to the existing app nav (for all users, not just admin):

```heex
<.nav_link href="/api-keys" icon="key" label="API Keys" active={@active_nav == :api_keys} />
```

- [ ] **Step 5: Add admin setup helper to live_view_helpers**

In `test/support/live_view_helpers.ex`, add:

```elixir
def setup_authenticated_admin(conn) do
  admin = FounderPad.Factory.create_admin_user!()
  org = FounderPad.Factory.create_organisation!()
  FounderPad.Factory.create_membership!(admin, org, :owner)

  token = AshAuthentication.user_to_subject(admin)

  conn =
    conn
    |> Plug.Test.init_test_session(%{"user_token" => token})

  {conn, admin, org}
end
```

- [ ] **Step 6: Run full test suite and commit**

```bash
mix test
git add -f lib/founder_pad_web/hooks/ lib/founder_pad_web/components/layouts/ test/support/
git commit -m "feat(admin): add impersonation, expanded admin nav, and test helpers"
```

---

## Verification

After all tasks are complete:

1. **Tests:** `mix test` — all pass
2. **Lint:** `mix credo` — no new warnings
3. **Manual testing:**
   - Start server: `PORT=4004 mix phx.server`
   - Visit `/admin` — admin dashboard with system stats
   - Visit `/admin/users` — user list with suspend/unsuspend
   - Visit `/admin/feature-flags` — toggle feature flags
   - Visit `/api-keys` — create API key, see raw key once, revoke it
   - Test API auth: `curl -H "Authorization: Bearer <raw_key>" localhost:4004/api/v1/agents`
   - View impersonation banner when impersonating
