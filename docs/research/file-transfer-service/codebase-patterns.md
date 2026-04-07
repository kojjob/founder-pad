# Codebase Analysis — LinkHub

## Ash Framework Notice

This project uses Ash Framework. Phoenix Context patterns do not apply. All domain modules are `Ash.Domain`, not Phoenix Contexts. Consult [ash-hq.org/docs](https://ash-hq.org/docs) for domain organization guidance.

---

## Project Structure

- **Web module**: `LinkHubWeb`
- **Business logic**: `LinkHub.{Domain}` — each is an `Ash.Domain`
- **App name**: `link_hub` (atom), `LinkHub` (module prefix)
- **Primary keys**: binary UUID via `uuid_primary_key(:id)`, configured globally with `migration_primary_key: [name: :id, type: :binary_id]`

---

## Phoenix Version and Modern Patterns

- **Phoenix version**: 1.8.0
- **LiveView**: 1.0
- **Verified routes**: Yes — `~p"/channels/#{channel.id}"` used in router and LiveViews
- **Scopes (Phoenix 1.8)**: Not used — no `%Scope{}` struct, no scope as first param in domain functions. Auth handled via Ash policies.
- **FallbackController**: Not present
- **PubSub in domains**: Yes — via `Ash.Notifier` (see MessageNotifier); PubSub broadcasts happen inside `notify/1` callbacks after successful Ash actions
- **LiveView on_mount hooks**: Three hooks chained in `:app` live_session — `AssignDefaults`, `RequireAuth`, `NotificationHandler`

---

## Domains Identified

| Domain | Module | Key Resources | Notes |
|--------|--------|---------------|-------|
| Accounts | `LinkHub.Accounts` | User, Workspace, Membership, Token | AshAuthentication |
| Messaging | `LinkHub.Messaging` | Channel, Message, ChannelMembership, Reaction, ReadReceipt | MessageNotifier broadcasts via PubSub |
| **Media** | **`LinkHub.Media`** | **FileAttachment** | **Target domain for File Transfer Service** |
| Billing | `LinkHub.Billing` | Plan, Subscription, Invoice, UsageRecord | Stripe via Oban worker |
| AI | `LinkHub.AI` | Agent, Conversation, Message, ToolCall | Oban worker + PubSub streaming |
| Notifications | `LinkHub.Notifications` | Notification, EmailLog | Mailers per domain |
| Audit | `LinkHub.Audit` | AuditLog | |
| FeatureFlags | `LinkHub.FeatureFlags` | FeatureFlag | |
| Webhooks | `LinkHub.Webhooks` | OutboundWebhook, WebhookDelivery | HMAC-signed delivery via Oban |
| Analytics | `LinkHub.Analytics` | AppEvent, SearchConsoleData | GSC sync via Oban |

All domains registered in `config :link_hub, ash_domains: [...]` in `config/config.exs`.

---

## Existing Media Domain — FileAttachment

**File**: `lib/link_hub/media/resources/file_attachment.ex`

Current state — a minimal record resource. Key observations:

### What exists
- Attributes: `filename`, `content_type`, `size_bytes`, `storage_path`, `timestamps()`
- Relationships: `belongs_to :workspace`, `belongs_to :uploader` (User), `belongs_to :message` (optional)
- Named read actions: `:list_by_message`, `:list_by_workspace`, `:search` (filename `contains` filter)
- Calculations: `:url` computed as `"/uploads/" <> storage_path`; `:is_image` boolean on `content_type`
- Policy: `authorize_if(always())` — **no real authorization enforced yet**

### What is missing / gaps to fill
- No upload worker / async processing
- No virus scanning, MIME validation, or size quota enforcement
- No storage abstraction (currently raw `File.cp!` to local disk in the LiveView)
- No signed URL / expiry support
- No workspace-scoped storage quotas
- No domain-defined function wrappers in `Media` domain module (only `create_attachment`, `get_attachment`, `list_attachments_for_message`, `search` are defined)
- `list_by_workspace` read action exists on resource but is NOT exposed via `define` in `Media` domain module

### Storage implementation (current)
Files are saved synchronously inside `ChannelLive.consume_uploaded_files/3`:
```elixir
# In lib/link_hub_web/live/channel_live.ex
consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
  ext = Path.extname(entry.client_name)
  unique_name = "#{Ash.UUID.generate()}#{ext}"
  dest = Path.join(uploads_dir(), unique_name)
  File.cp!(path, dest)
  {:ok, %{filename: ..., storage_path: unique_name, ...}}
end)
```
Storage path: `Application.app_dir(:link_hub, "priv/static/uploads")` — local disk only.
URL pattern: `/uploads/:storage_path` — served as static files.

---

## Ash Resource Patterns

### Pattern 1 — Messaging.Message (exemplary: named actions, soft delete, aggregates, notifier)

```elixir
use Ash.Resource,
  domain: LinkHub.Messaging,
  data_layer: AshPostgres.DataLayer,
  authorizers: [Ash.Policy.Authorizer],
  notifiers: [LinkHub.Messaging.Notifiers.MessageNotifier]

# Named create action with argument → relationship management
create :send do
  accept([:body, :channel_id, :parent_message_id])
  argument(:author_id, :uuid, allow_nil?: false)
  change(manage_relationship(:author_id, :author, type: :append))
end

# Soft delete pattern
update :soft_delete do
  change(set_attribute(:deleted_at, &DateTime.utc_now/0))
  change(set_attribute(:body, "[deleted]"))
end

# Aggregate
aggregates do
  count :reply_count, :replies do
    filter(expr(is_nil(deleted_at)))
  end
end
```

Key: `deleted_at` soft delete on `utc_datetime_usec` column. Filters use `is_nil(deleted_at)` in read actions.

### Pattern 2 — Accounts.User (exemplary: AshAuthentication, policy with actor check, change on create)

```elixir
# Policy pattern — actor-scoped mutation authorization
policy action_type([:update, :destroy]) do
  authorize_if(expr(id == ^actor(:id)))
end

# Change registered for specific action condition
changes do
  change(LinkHub.Accounts.Changes.SendWelcomeEmail,
    on: [:create],
    where: [action_is(:register_with_password)]
  )
end
```

### Pattern 3 — Billing.Plan / Membership (exemplary: arguments for FK management)

```elixir
# All FK relationships go through arguments + manage_relationship, never direct FK accept
create :create do
  accept([:role])
  argument(:user_id, :uuid, allow_nil?: false)
  argument(:workspace_id, :uuid, allow_nil?: false)
  change(manage_relationship(:user_id, :user, type: :append))
  change(manage_relationship(:workspace_id, :workspace, type: :append))
end
```

---

## PubSub Pattern

The established pattern is: **Ash.Notifier broadcasts, LiveView subscribes**.

```elixir
# Notifier (lib/link_hub/messaging/notifiers/message_notifier.ex)
use Ash.Notifier

def notify(%Ash.Notifier.Notification{resource: Message, action: %{name: :send}} = notif) do
  Phoenix.PubSub.broadcast(LinkHub.PubSub, "channel:#{message.channel_id}", {:new_message, message})
  :ok
end

# LiveView subscribes in load_channel/3 — only when connected
if connected?(socket) do
  Phoenix.PubSub.subscribe(LinkHub.PubSub, "channel:#{channel.id}")
end

# LiveView handles
def handle_info({:new_message, message}, socket) do ...
```

PubSub topic naming convention: `"resource_type:#{id}"` — e.g. `"channel:#{id}"`, `"conversation:#{id}"`, `"thread:#{id}"`.

For a File Transfer Service, the natural topic would be `"upload:#{upload_job_id}"` for progress broadcasting.

---

## Oban Worker Patterns

Three workers exist, all consistent:

```elixir
use Oban.Worker, queue: :billing, max_attempts: 5

@impl Oban.Worker
def perform(%Oban.Job{args: %{"string_key" => value}}) do
  # ...
  :ok             # success
  {:error, reason} # failure — Oban will retry up to max_attempts
end
```

Rules observed across all workers:
1. Args destructured with **string keys** (not atoms) — correct Oban pattern
2. No structs in args — only primitives and IDs
3. Return `:ok` or `{:error, reason}` — nothing else
4. Logger calls at info/error/warning throughout
5. Ash queries inside workers use `Ash.Query.filter/2` with `^` pinning
6. Workers handle `{:ok, []} -> :ok` gracefully (not found = not error, to prevent infinite retries on missing records)

**Oban queues** (from `config/config.exs`):
```
queues: [default: 10, mailers: 20, billing: 5, ai: 3]
```
No `media` queue exists yet. A file processing queue would need to be added here.

---

## LiveView Upload Pattern (existing, in ChannelLive)

```elixir
# In mount:
|> allow_upload(:file, accept: :any, max_entries: 5, max_file_size: 20_000_000)

# Event handler:
def handle_event("validate_upload", _params, socket), do: {:noreply, socket}
def handle_event("cancel_upload", %{"ref" => ref}, socket) do
  {:noreply, cancel_upload(socket, :file, ref)}
end

# In form: phx-drop-target={@uploads.file.ref}
# File input: <.live_file_input upload={@uploads.file} class="hidden" />

# Consume:
consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
  # File.cp! path → destination
  {:ok, file_attrs_map}
end)
```

FileAttachment records are created **after** message creation, linking them via `message_id`.

---

## Auth and Authorization Pattern

- Authentication: AshAuthentication with password + magic_link strategies
- Session: `AuthSessionController` sets/clears session cookie
- LiveView auth: `RequireAuth` on_mount hook (checks `socket.assigns[:current_user]`)
- Resource-level: Ash policies with `authorize_if` — currently most resources use `authorize_if(always())` (permissive/placeholder policies)
- No actor passed to Ash calls in workers or LiveView — this is an area of technical debt. Calls like `Ash.create()` without an actor bypass policy enforcement in practice

---

## Router Structure

```
/auth/*             — browser pipeline, AuthSessionController + Login/Register LiveViews
/                   — browser, public LiveViews (landing, docs, onboarding)
/dashboard, /channels, /agents, etc.
                    — :app live_session (AssignDefaults + RequireAuth + NotificationHandler)
/webhooks/stripe    — api pipeline, no CSRF
/api/v1/*           — api pipeline, JsonApiRouter (AshJsonApi)
/api/graphql        — api pipeline, Absinthe
```

Static files (including uploads) served from `priv/static/`. Uploads directory: `priv/static/uploads/`.

---

## JS Hooks Pattern

Located in `assets/js/hooks/` (individual files), registered in `app.js`:
```js
import ThemeToggle from "./hooks/theme_toggle"
// ...
const liveSocket = new LiveSocket("/live", Socket, {
  hooks: {ThemeToggle, Analytics, ScrollReveal, AutoDismiss, ThemeSettings, ScrollBottom},
})
```

`ScrollBottom` is defined inline in `app.js` (not a separate file — exception for simple hooks). Hook lifecycle: `mounted()`, `updated()`, `destroyed()`.

For upload progress reporting, a `UploadProgress` hook following this pattern would be the right approach.

---

## Testing Patterns

- **Factory**: Custom factory module (`LinkHub.Factory`) in `test/support/factory.ex` — NOT ExMachina despite it being a dep. Functions are `create_*!` / `build_*` style, calling `Ash.Changeset.for_create/3 |> Ash.create!()` directly.
- **DataCase**: Uses `Ecto.Adapters.SQL.Sandbox`, `shared: not tags[:async]`
- **Async**: Tests with `async: true` when they don't share mutable state
- **No Mox/Hammox**: No mocking library in use — tests hit the real database
- **Test organization**: `test/link_hub/` for domain tests, `test/link_hub_web/` for web tests

To add a FileAttachment factory function, follow the `create_messaging_context!` style pattern — build up the dependency chain and return a tuple.

---

## Dependencies — Storage

No cloud storage library present. Current deps relevant to file transfer:
- `req ~> 0.5` — HTTP client (for external calls)
- `jason ~> 1.4` — JSON
- No `ex_aws`, `waffle`, `arc`, `ex_aws_s3`, or any object storage lib

For production-ready file storage, `ex_aws` + `ex_aws_s3` would need to be added to `mix.exs`. The current implementation is local disk only.

---

## Anti-patterns Found

1. **FileAttachment policy is `authorize_if(always())`** — no real enforcement. Any user can read/create/destroy any attachment.
2. **Ash calls in workers without actor** — `Ash.create()` called without `actor:` option, relying on `authorize_if(always())` being permissive.
3. **Direct cross-domain resource reference in Message** — `has_many :attachments, LinkHub.Media.FileAttachment` in `Messaging.Message` — crosses domain boundary at the resource level.
4. **Synchronous file copy in LiveView** — `File.cp!` blocks the LiveView process during upload consumption. For large files, this should be offloaded to an Oban worker.
5. **No stream for message list** — `@messages` is a plain list, not a LiveView stream. Will cause performance issues at scale.
6. **`list_by_workspace` action not exposed** in `Media` domain module `define` block.
7. **Local disk storage only** — not suitable for multi-node or containerized deployment.

---

## Quick Reference for File Transfer Service

### Schema Location
New resources for file transfer processing should live in `lib/link_hub/media/resources/`.

### Resource Pattern to Follow
Follow `LinkHub.Messaging.Message` for:
- Named actions (e.g., `:upload`, `:process`, `:expire`)
- `manage_relationship` for FKs
- Notifier for PubSub broadcasts

Follow `LinkHub.Billing.Workers.StripeHandler` for:
- Oban worker queue assignment
- String key arg destructuring
- Graceful `{:ok, []} -> :ok` not-found handling

### New Oban Queue Needed
Add `media: 5` to `queues` in `config/config.exs` Oban config.

### PubSub Topic Convention
Use `"upload:#{upload_id}"` for per-upload progress events.

### LiveView Upload Entry Point
Extend `consume_uploaded_files/3` in `ChannelLive` (or extract to a shared helper) to enqueue an Oban job instead of calling `File.cp!` synchronously.

### Testing Pattern
Add `create_file_attachment!` factory function to `LinkHub.Factory` following the `create_messaging_context!` style.

### Auth Pattern
Pass `actor: current_user` to all Ash calls when building new resources — do not rely on `authorize_if(always())`.
