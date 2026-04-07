# Ash 3.x Patterns for the Media / File Domain

Researched against Ash 3.5.x (the version locked in mix.exs `~> 3.0`).
All patterns are cross-checked against the existing codebase under
`lib/link_hub/` so examples follow the project's own conventions.

---

## 1. Calculations

### Expression-based (inline, no module needed)

Use for anything the database can evaluate directly.

```elixir
calculations do
  # Already used in FileAttachment — concatenate a prefix with a stored path
  calculate :url, :string, expr("/uploads/" <> storage_path)

  # Boolean derived from another attribute
  calculate :is_image, :boolean, expr(contains(content_type, "image/"))

  # Arithmetic — quota remaining
  calculate :bytes_remaining, :integer,
            expr(quota_bytes - used_bytes)
end
```

Load them explicitly — they are NOT included by default:

```elixir
Ash.get!(LinkHub.Media.FileAttachment, id, load: [:url, :is_image])
# or in a read action prepare:
prepare(build(load: [:url]))
```

### Module-based (for logic that cannot be pushed to the database)

Use when the URL depends on runtime config (e.g. an S3 presigned URL that
requires a secret key from Application.get_env).

```elixir
# lib/link_hub/media/calculations/storage_url.ex
defmodule LinkHub.Media.Calculations.StorageUrl do
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    # Return the attribute names this calculation reads from each record.
    # Ash will ensure these are loaded before calculate/3 is called.
    [:storage_path]
  end

  @impl true
  def calculate(records, _opts, _context) do
    base_url = Application.get_env(:link_hub, :storage_base_url, "")

    Enum.map(records, fn record ->
      base_url <> "/" <> record.storage_path
    end)
  end
end
```

Declare in the resource DSL:

```elixir
calculations do
  calculate :url, :string, LinkHub.Media.Calculations.StorageUrl
end
```

With options (e.g. configurable expiry):

```elixir
# Module with opts — pass a tuple {Module, opts}
calculate :presigned_url, :string, {LinkHub.Media.Calculations.PresignedUrl, expires_in: 3600}
```

The `init/1` callback validates opts:

```elixir
@impl true
def init(opts) do
  if Keyword.get(opts, :expires_in) do
    {:ok, opts}
  else
    {:error, "requires :expires_in option"}
  end
end
```

### calculate/3 full signature

```elixir
@callback calculate(
  records  :: [Ash.Resource.record()],
  opts     :: Keyword.t(),
  context  :: Ash.Resource.Calculation.Context.t()
) :: {:ok, [term()]} | [term()] | {:error, term()} | :unknown
```

The `context` struct exposes `context.arguments` (a map of named arguments
passed at load time) and `context.actor`.

### load/3 return values

```elixir
# Single atom
def load(_q, _o, _c), do: :storage_path

# List of atoms (most common)
def load(_q, _o, _c), do: [:storage_path, :content_type]

# Keyword list to also load relationships
def load(_q, _o, _c), do: [workspace: [:slug]]
```

---

## 2. Policies

### Pattern observed in this codebase

Current resources (`Channel`, `Membership`) keep policies simple.
`FileAttachment` uses `authorize_if(always())` as a placeholder.

### Workspace-scoped read policy (correct pattern)

```elixir
policies do
  # Any actor who is a member of the workspace may read its files
  policy action_type(:read) do
    authorize_if expr(workspace_id == ^actor(:workspace_id))
  end

  # Uploader can destroy their own file
  policy action_type(:destroy) do
    authorize_if expr(uploader_id == ^actor(:id))
  end

  # Workspace admins/owners can destroy any file in their workspace
  policy action(:destroy) do
    authorize_if expr(workspace_id == ^actor(:workspace_id) and
                       ^actor(:role) in [:admin, :owner])
  end
end
```

### relates_to_actor_via — for relationship-path checks

When the actor's workspace context is not a direct scalar attribute but
needs to be confirmed via a relationship:

```elixir
policy action_type(:read) do
  # Passes if the record's :workspace relationship connects back to the actor
  # through the workspace's :memberships relationship
  authorize_if relates_to_actor_via([:workspace, :members])
end
```

This traverses `file_attachment.workspace.members` and checks if the
actor is in that set. Useful when the actor does not carry `workspace_id`
as a top-level attribute.

### expr() macro reference

```elixir
# Compare record attribute to actor scalar attribute
authorize_if expr(workspace_id == ^actor(:workspace_id))

# Check actor attribute (role stored on actor struct)
authorize_if expr(^actor(:role) in [:admin, :owner])

# Combine conditions
authorize_if expr(workspace_id == ^actor(:workspace_id) and
                   uploader_id == ^actor(:id))

# Always allow (use as placeholder, remove for production)
authorize_if always()

# Bypass for super-admins
bypass actor_attribute_equals(:super_admin, true) do
  authorize_if always()
end
```

### Policy evaluation order

Ash evaluates policies **top to bottom**. The first check that produces a
definitive result (`:authorized` or `:forbidden`) stops evaluation.
Use `bypass` blocks before ordinary `policy` blocks for admin overrides.

---

## 3. Ash Domain `define` blocks

### Signature

```elixir
define :function_name, action: :action_name
define :function_name, action: :action_name, args: [:arg1, :arg2]
define :function_name, action: :action_name, get?: true          # single result
define :function_name, action: :action_name, get_by: [:id]       # sugar for filter + get?
```

### How `args` maps

`args` lifts specific action **arguments or accepted attributes** into
positional function parameters on the generated function.

```elixir
# In domain:
define :create_attachment, action: :create, args: [:workspace_id, :uploader_id]

# Generates a function with this calling convention:
LinkHub.Media.create_attachment(workspace_id, uploader_id, %{filename: ..., ...}, opts)
# The remaining accepted attrs are passed as a map in the next positional argument.
```

When `args` is omitted, all inputs are passed as a single map:

```elixir
LinkHub.Media.create_attachment(%{workspace_id: ..., uploader_id: ..., filename: ...})
```

### Return types

| Situation | Return |
|---|---|
| Create/Update/Destroy (default) | `{:ok, record}` or `{:error, changeset}` |
| Read (list) | `{:ok, [record]}` or `{:error, error}` |
| `get?: true` or `get_by:` | `{:ok, record}` or `{:ok, nil}` or `{:error, error}` |

Bang variants are auto-generated too: `create_attachment!` raises on error.

### Full example matching this project's domain style

```elixir
defmodule LinkHub.Media do
  use Ash.Domain

  resources do
    resource LinkHub.Media.FileAttachment do
      define :create_attachment, action: :create
      define :get_attachment,    action: :read, get_by: [:id]
      define :list_attachments_for_message, action: :list_by_message
      define :list_attachments_for_workspace, action: :list_by_workspace
      define :search_attachments, action: :search
      define :delete_attachment, action: :destroy
    end
  end
end
```

---

## 4. Ash.Notifier — broadcast file upload events

### Pattern confirmed from `MessageNotifier` in this codebase

```elixir
# lib/link_hub/media/notifiers/file_notifier.ex
defmodule LinkHub.Media.Notifiers.FileNotifier do
  @moduledoc """
  Broadcasts file upload/delete events via PubSub after Ash action commits.
  Runs after transaction — safe to broadcast to subscribers.
  """
  use Ash.Notifier

  @impl true
  def notify(%Ash.Notifier.Notification{
        resource: LinkHub.Media.FileAttachment,
        action: %{name: :create},
        data: file
      }) do
    Phoenix.PubSub.broadcast(
      LinkHub.PubSub,
      "workspace:#{file.workspace_id}:files",
      {:file_uploaded, file}
    )

    :ok
  end

  def notify(%Ash.Notifier.Notification{
        resource: LinkHub.Media.FileAttachment,
        action: %{name: :destroy},
        data: file
      }) do
    Phoenix.PubSub.broadcast(
      LinkHub.PubSub,
      "workspace:#{file.workspace_id}:files",
      {:file_deleted, file}
    )

    :ok
  end

  # Catch-all — must return :ok, never raise
  def notify(_notification), do: :ok
end
```

Register the notifier on the resource:

```elixir
use Ash.Resource,
  domain: LinkHub.Media,
  data_layer: AshPostgres.DataLayer,
  authorizers: [Ash.Policy.Authorizer],
  notifiers: [LinkHub.Media.Notifiers.FileNotifier]
```

### Key behaviour details

- `notify/1` runs **after transaction commit** — guaranteed no in-transaction state
- Must return `:ok` — raise or return errors to crash the notifier process only
- `requires_original_data?/2` callback: return `true` if the notification needs
  the record's previous state (e.g. for `:update` to compare before/after)
- Pattern-match on `action: %{name: :action_name}` (not `action: %{type: :create}`)
  when you need a specific named action, not just an action type category

### Notification struct fields

| Field | Contains |
|---|---|
| `resource` | The resource module (e.g. `LinkHub.Media.FileAttachment`) |
| `action` | Action struct — match on `%{name: :create}` or `%{type: :create}` |
| `data` | The resulting record after the action |
| `changeset` | The changeset used; useful in `:update` to inspect changes |
| `actor` | The actor who triggered the action (may be `nil`) |
| `domain` | The domain module |

---

## 5. File-Related Attribute Patterns

### Enum / status field (two valid approaches)

**Approach A — inline `:atom` with constraints (used in `Channel`, `Membership`):**

```elixir
attribute :status, :atom do
  constraints(one_of: [:pending, :processing, :ready, :failed])
  default(:pending)
  allow_nil?(false)
  public?(true)
end
```

**Approach B — dedicated `Ash.Type.Enum` module (preferred for reuse):**

```elixir
# lib/link_hub/media/types/file_status.ex
defmodule LinkHub.Media.Types.FileStatus do
  use Ash.Type.Enum, values: [:pending, :processing, :ready, :failed]
end
```

```elixir
attribute :status, LinkHub.Media.Types.FileStatus do
  default(:pending)
  allow_nil?(false)
  public?(true)
end
```

`Ash.Type.Enum` auto-accepts atoms, strings, and case-insensitive strings,
which is useful for JSON API input. For internal-only enums the inline
constraints approach is sufficient.

### Map attribute for metadata

Stores a JSON object (`jsonb` in Postgres via AshPostgres):

```elixir
attribute :metadata, :map do
  default(%{})
  allow_nil?(false)
  public?(true)
end
```

Access in expressions: `metadata["key"]`.

For typed metadata with validation, use `:map` with constraints or
define an embedded resource (more overhead, more validation):

```elixir
attribute :metadata, :map do
  constraints fields: [
    width:  [type: :integer],
    height: [type: :integer],
    duration_ms: [type: :integer]
  ]
end
```

### Decimal attribute (e.g. quota in GB, never for money)

```elixir
attribute :quota_gb, :decimal do
  allow_nil?(false)
  default(Decimal.new("1.0"))
  public?(true)
end
```

**Note:** For money/billing use `:integer` (cents). For file sizes use
`:integer` (bytes) — `size_bytes` is already the pattern in `FileAttachment`.
`:decimal` is appropriate for quota thresholds expressed as fractional GB values.

### Integer size with validation constraint

```elixir
attribute :size_bytes, :integer do
  allow_nil?(false)
  constraints min: 0, max: 524_288_000   # 500 MB cap
  public?(true)
end
```

---

## 6. Summary of Patterns to Follow / Avoid

| Do | Do not |
|---|---|
| `expr(...)` inline calculations for DB-pushable logic | Module calculations for simple string concatenation |
| `Ash.Type.Enum` module when the enum is used across resources | `:float` for sizes or money |
| Pattern match on `action: %{name: :action_name}` in notifiers | Pattern match on `action: %{type: :create}` when you mean a specific action |
| Register notifier via `notifiers:` option on `use Ash.Resource` | Manually calling PubSub from inside action `change` blocks |
| `relates_to_actor_via` for multi-hop relationship checks | Direct Ecto queries to check membership — use Ash policies |
| `get_by: [:id]` in domain `define` for single-record lookups | Returning lists when a single record is expected |
| Catch-all `def notify(_notification), do: :ok` as the last clause | Raising from `notify/1` |

---

## Compatibility Notes

- Elixir: `~> 1.17` (project constraint)
- Ash: `~> 3.0` (resolved to 3.5.x in lock)
- AshPostgres: `~> 2.0`
- AshAuthentication: `~> 4.0`
- Phoenix / LiveView: `1.8` / `1.0`
- No additional libraries needed — all patterns above use Ash 3.x built-ins
