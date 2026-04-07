# Content Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete Blog CMS with WYSIWYG editor, SEO engine with meta tags/JSON-LD/sitemap, and dynamic changelog — all powered by a new `FounderPad.Content` Ash domain.

**Architecture:** New `Content` Ash domain with 6 resources (Post, Category, Tag, PostCategory, PostTag, ChangelogEntry). Blog content is global (not org-scoped), authored by admin users (`is_admin` boolean on User). Tiptap WYSIWYG editor via LiveView JS hook. Public pages at `/blog/*` and `/changelog`. Admin CRUD at `/admin/*`.

**Tech Stack:** Ash Framework 3.x, Phoenix LiveView 1.0, Tiptap (ProseMirror), TailwindCSS 4.x, Oban (scheduled publishing), PostgreSQL

---

## File Structure

### New Files

```
lib/founder_pad/content/
  content.ex                              # Ash Domain module
  resources/
    post.ex                               # Blog post resource
    category.ex                           # Blog category resource
    tag.ex                                # Blog tag resource
    post_category.ex                      # Join table resource
    post_tag.ex                           # Join table resource
    changelog_entry.ex                    # Changelog entry resource
  changes/
    generate_slug.ex                      # Reusable slug generation change
    calculate_reading_time.ex             # Reading time from body word count
  seo_scorer.ex                           # Pure function SEO score calculator
  workers/
    publish_scheduled_posts_worker.ex     # Oban cron worker

lib/founder_pad_web/live/
  blog/
    blog_index_live.ex                    # /blog - paginated post listing
    blog_post_live.ex                     # /blog/:slug - single post
    blog_category_live.ex                 # /blog/category/:slug
    blog_tag_live.ex                      # /blog/tag/:slug
  admin/
    blog_list_live.ex                     # /admin/blog - post management
    blog_editor_live.ex                   # /admin/blog/new and /admin/blog/:id/edit
    blog_categories_live.ex              # /admin/blog/categories
    blog_tags_live.ex                     # /admin/blog/tags
    changelog_list_live.ex               # /admin/changelog
    changelog_editor_live.ex             # /admin/changelog/new and :id/edit
    seo_dashboard_live.ex                # /admin/seo

lib/founder_pad_web/controllers/
  feed_controller.ex                     # RSS feeds for blog + changelog

lib/founder_pad_web/hooks/
  require_admin.ex                       # on_mount hook for admin routes

lib/founder_pad_web/components/
  blog_components.ex                     # Blog-specific function components
  seo_components.ex                      # SEO meta tag + JSON-LD components

assets/js/hooks/
  tiptap_editor.js                       # Tiptap WYSIWYG LiveView hook

priv/repo/migrations/
  YYYYMMDD_add_is_admin_to_users.exs
  YYYYMMDD_create_content_tables.exs

test/founder_pad/content/
  post_test.exs
  category_test.exs
  tag_test.exs
  changelog_entry_test.exs
  seo_scorer_test.exs
  generate_slug_test.exs

test/founder_pad_web/live/
  blog/
    blog_index_live_test.exs
    blog_post_live_test.exs
  admin/
    blog_list_live_test.exs
    blog_editor_live_test.exs
    changelog_list_live_test.exs

test/founder_pad_web/controllers/
  feed_controller_test.exs
```

### Modified Files

```
lib/founder_pad/accounts/resources/user.ex     # Add is_admin attribute
config/config.exs                               # Register Content domain, Oban cron
mix.exs                                         # No new Elixir deps needed
assets/js/app.js                                # Register TiptapEditor hook
assets/package.json                             # Add Tiptap npm deps
lib/founder_pad_web/router.ex                   # All new routes
lib/founder_pad_web/controllers/sitemap_controller.ex  # Include blog URLs
lib/founder_pad_web/live/docs/changelog_live.ex        # Refactor to DB-backed
lib/founder_pad_web/components/layouts/app.html.heex   # Admin nav links
lib/founder_pad_web/components/layouts/root.html.heex  # SEO meta tags
test/support/factory.ex                                # Blog factories
```

---

## Task 1: Add `is_admin` to User Resource

**Files:**
- Modify: `lib/founder_pad/accounts/resources/user.ex`
- Create: `priv/repo/migrations/YYYYMMDD_add_is_admin_to_users.exs`
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Add `is_admin` attribute to User resource**

In `lib/founder_pad/accounts/resources/user.ex`, add inside the `attributes do` block, after the existing attributes:

```elixir
attribute :is_admin, :boolean do
  default false
  allow_nil? false
  public? true
end
```

- [ ] **Step 2: Generate and run migration**

Run:
```bash
mix ash.codegen add_is_admin_to_users
mix ecto.migrate
```

- [ ] **Step 3: Add admin factory helper**

In `test/support/factory.ex`, add:

```elixir
def create_admin_user!(attrs \\ %{}) do
  {:ok, user} =
    FounderPad.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: unique_email(),
      password: "Password123!",
      password_confirmation: "Password123!"
    })
    |> Ash.create()

  user
  |> Ash.Changeset.for_update(:update, %{is_admin: true})
  |> Ash.update!()
end
```

- [ ] **Step 4: Verify compilation and tests pass**

Run:
```bash
mix compile --warnings-as-errors
mix test
```
Expected: All existing tests pass, no warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/founder_pad/accounts/resources/user.ex priv/repo/migrations/*is_admin* test/support/factory.ex
git commit -m "feat(accounts): add is_admin boolean to User resource"
```

---

## Task 2: Create Ash Changes (GenerateSlug + CalculateReadingTime)

**Files:**
- Create: `lib/founder_pad/content/changes/generate_slug.ex`
- Create: `lib/founder_pad/content/changes/calculate_reading_time.ex`
- Create: `test/founder_pad/content/generate_slug_test.exs`

- [ ] **Step 1: Write failing test for slug generation**

Create `test/founder_pad/content/generate_slug_test.exs`:

```elixir
defmodule FounderPad.Content.Changes.GenerateSlugTest do
  use FounderPad.DataCase, async: true

  alias FounderPad.Content.Changes.GenerateSlug

  describe "slugify/1" do
    test "converts title to slug" do
      assert GenerateSlug.slugify("Hello World") == "hello-world"
    end

    test "handles special characters" do
      assert GenerateSlug.slugify("What's New in v2.0?") == "whats-new-in-v20"
    end

    test "handles multiple spaces and dashes" do
      assert GenerateSlug.slugify("  Multiple   Spaces  ") == "multiple-spaces"
    end

    test "handles unicode" do
      assert GenerateSlug.slugify("Café & Résumé") == "cafe-resume"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/founder_pad/content/generate_slug_test.exs`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement GenerateSlug change**

Create `lib/founder_pad/content/changes/generate_slug.ex`:

```elixir
defmodule FounderPad.Content.Changes.GenerateSlug do
  @moduledoc "Ash change that auto-generates a URL slug from a title attribute."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :title) do
      nil ->
        changeset

      title ->
        slug = Ash.Changeset.get_attribute(changeset, :slug)

        if is_nil(slug) or slug == "" do
          Ash.Changeset.force_change_attribute(changeset, :slug, slugify(title))
        else
          changeset
        end
    end
  end

  @doc "Converts a string to a URL-safe slug."
  def slugify(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.trim()
    |> String.replace(~r/[\s-]+/, "-")
    |> String.trim("-")
  end

  def slugify(_), do: ""
end
```

- [ ] **Step 4: Implement CalculateReadingTime change**

Create `lib/founder_pad/content/changes/calculate_reading_time.ex`:

```elixir
defmodule FounderPad.Content.Changes.CalculateReadingTime do
  @moduledoc "Ash change that calculates reading time in minutes from HTML body content."
  use Ash.Resource.Change

  @words_per_minute 200

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :body) do
      nil ->
        changeset

      body ->
        minutes = calculate(body)
        Ash.Changeset.force_change_attribute(changeset, :reading_time_minutes, minutes)
    end
  end

  @doc "Calculate reading time in minutes from HTML content."
  def calculate(html) when is_binary(html) do
    word_count =
      html
      |> String.replace(~r/<[^>]+>/, " ")
      |> String.split(~r/\s+/, trim: true)
      |> length()

    max(1, div(word_count + @words_per_minute - 1, @words_per_minute))
  end

  def calculate(_), do: 1
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/founder_pad/content/generate_slug_test.exs`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/founder_pad/content/changes/ test/founder_pad/content/generate_slug_test.exs
git commit -m "feat(content): add GenerateSlug and CalculateReadingTime Ash changes"
```

---

## Task 3: Create Content Domain Resources

**Files:**
- Create: `lib/founder_pad/content/content.ex`
- Create: `lib/founder_pad/content/resources/category.ex`
- Create: `lib/founder_pad/content/resources/tag.ex`
- Create: `lib/founder_pad/content/resources/post_category.ex`
- Create: `lib/founder_pad/content/resources/post_tag.ex`
- Create: `lib/founder_pad/content/resources/post.ex`
- Create: `lib/founder_pad/content/resources/changelog_entry.ex`
- Modify: `config/config.exs`

- [ ] **Step 1: Create Category resource**

Create `lib/founder_pad/content/resources/category.ex`:

```elixir
defmodule FounderPad.Content.Category do
  use Ash.Resource,
    domain: FounderPad.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "blog_categories"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    many_to_many :posts, FounderPad.Content.Post do
      through FounderPad.Content.PostCategory
      source_attribute_on_join_resource :category_id
      destination_attribute_on_join_resource :post_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :slug, :description]
      change FounderPad.Content.Changes.GenerateSlug
    end

    update :update do
      accept [:name, :slug, :description]
    end
  end

  policies do
    policy action(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:is_admin) == true)
    end
  end
end
```

- [ ] **Step 2: Create Tag resource**

Create `lib/founder_pad/content/resources/tag.ex`:

```elixir
defmodule FounderPad.Content.Tag do
  use Ash.Resource,
    domain: FounderPad.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "blog_tags"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    many_to_many :posts, FounderPad.Content.Post do
      through FounderPad.Content.PostTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :post_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :slug]
      change FounderPad.Content.Changes.GenerateSlug
    end

    update :update do
      accept [:name, :slug]
    end
  end

  policies do
    policy action(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:is_admin) == true)
    end
  end
end
```

- [ ] **Step 3: Create PostCategory join resource**

Create `lib/founder_pad/content/resources/post_category.ex`:

```elixir
defmodule FounderPad.Content.PostCategory do
  use Ash.Resource,
    domain: FounderPad.Content,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "blog_post_categories"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :post, FounderPad.Content.Post do
      allow_nil? false
      primary_key? true
    end

    belongs_to :category, FounderPad.Content.Category do
      allow_nil? false
      primary_key? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:post_id, :category_id]
    end
  end

  identities do
    identity :unique_post_category, [:post_id, :category_id]
  end
end
```

- [ ] **Step 4: Create PostTag join resource**

Create `lib/founder_pad/content/resources/post_tag.ex`:

```elixir
defmodule FounderPad.Content.PostTag do
  use Ash.Resource,
    domain: FounderPad.Content,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "blog_post_tags"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :post, FounderPad.Content.Post do
      allow_nil? false
      primary_key? true
    end

    belongs_to :tag, FounderPad.Content.Tag do
      allow_nil? false
      primary_key? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:post_id, :tag_id]
    end
  end

  identities do
    identity :unique_post_tag, [:post_id, :tag_id]
  end
end
```

- [ ] **Step 5: Create Post resource**

Create `lib/founder_pad/content/resources/post.ex`:

```elixir
defmodule FounderPad.Content.Post do
  use Ash.Resource,
    domain: FounderPad.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "blog_posts"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :body, :string do
      public? true
      constraints max_length: 500_000
    end

    attribute :excerpt, :string do
      public? true
      constraints max_length: 500
    end

    attribute :featured_image_url, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :scheduled, :archived]
      default :draft
      allow_nil? false
      public? true
    end

    attribute :published_at, :utc_datetime_usec do
      public? true
    end

    attribute :scheduled_at, :utc_datetime_usec do
      public? true
    end

    attribute :reading_time_minutes, :integer do
      default 1
      public? true
    end

    # SEO fields
    attribute :meta_title, :string do
      public? true
      constraints max_length: 70
    end

    attribute :meta_description, :string do
      public? true
      constraints max_length: 160
    end

    attribute :og_image_url, :string do
      public? true
    end

    attribute :canonical_url, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end

  relationships do
    belongs_to :author, FounderPad.Accounts.User do
      allow_nil? false
      attribute_type :uuid
    end

    many_to_many :categories, FounderPad.Content.Category do
      through FounderPad.Content.PostCategory
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :category_id
    end

    many_to_many :tags, FounderPad.Content.Tag do
      through FounderPad.Content.PostTag
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :title, :slug, :body, :excerpt, :featured_image_url, :status,
        :published_at, :scheduled_at, :meta_title, :meta_description,
        :og_image_url, :canonical_url, :author_id
      ]

      change FounderPad.Content.Changes.GenerateSlug
      change FounderPad.Content.Changes.CalculateReadingTime
    end

    update :update do
      accept [
        :title, :slug, :body, :excerpt, :featured_image_url, :status,
        :published_at, :scheduled_at, :meta_title, :meta_description,
        :og_image_url, :canonical_url
      ]

      change FounderPad.Content.Changes.CalculateReadingTime
    end

    update :publish do
      change set_attribute(:status, :published)
      change set_attribute(:published_at, &DateTime.utc_now/0)
    end

    update :schedule do
      accept [:scheduled_at]
      change set_attribute(:status, :scheduled)
    end

    update :archive do
      change set_attribute(:status, :archived)
    end

    read :published do
      filter expr(status == :published and published_at <= now())
      prepare build(sort: [published_at: :desc])
    end

    read :by_slug do
      argument :slug, :string, allow_nil?: false
      filter expr(slug == ^arg(:slug) and status == :published)
      prepare build(load: [:author, :categories, :tags])
    end

    read :scheduled_ready do
      filter expr(status == :scheduled and scheduled_at <= now())
    end
  end

  policies do
    policy action([:published, :by_slug]) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:is_admin) == true)
    end

    policy action(:read) do
      authorize_if expr(^actor(:is_admin) == true)
    end

    policy action(:scheduled_ready) do
      authorize_if always()
    end
  end
end
```

- [ ] **Step 6: Create ChangelogEntry resource**

Create `lib/founder_pad/content/resources/changelog_entry.ex`:

```elixir
defmodule FounderPad.Content.ChangelogEntry do
  use Ash.Resource,
    domain: FounderPad.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "changelog_entries"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :version, :string do
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :body, :string do
      public? true
      constraints max_length: 100_000
    end

    attribute :type, :atom do
      constraints one_of: [:feature, :fix, :improvement, :breaking]
      default :feature
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published]
      default :draft
      allow_nil? false
      public? true
    end

    attribute :published_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :author, FounderPad.Accounts.User do
      allow_nil? false
      attribute_type :uuid
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:version, :title, :body, :type, :status, :published_at, :author_id]
    end

    update :update do
      accept [:version, :title, :body, :type, :status]
    end

    update :publish do
      change set_attribute(:status, :published)
      change set_attribute(:published_at, &DateTime.utc_now/0)
    end

    read :published do
      filter expr(status == :published)
      prepare build(sort: [published_at: :desc])
    end
  end

  policies do
    policy action(:published) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:is_admin) == true)
    end

    policy action(:read) do
      authorize_if expr(^actor(:is_admin) == true)
    end
  end
end
```

- [ ] **Step 7: Create Content domain module**

Create `lib/founder_pad/content/content.ex`:

```elixir
defmodule FounderPad.Content do
  use Ash.Domain

  resources do
    resource FounderPad.Content.Post do
      define :create_post, action: :create
      define :update_post, action: :update
      define :publish_post, action: :publish
      define :schedule_post, action: :schedule
      define :archive_post, action: :archive
      define :list_published_posts, action: :published
      define :get_post_by_slug, action: :by_slug, args: [:slug]
      define :list_scheduled_ready, action: :scheduled_ready
    end

    resource FounderPad.Content.Category do
      define :create_category, action: :create
      define :update_category, action: :update
      define :list_categories, action: :read
    end

    resource FounderPad.Content.Tag do
      define :create_tag, action: :create
      define :update_tag, action: :update
      define :list_tags, action: :read
    end

    resource FounderPad.Content.PostCategory
    resource FounderPad.Content.PostTag

    resource FounderPad.Content.ChangelogEntry do
      define :create_changelog_entry, action: :create
      define :update_changelog_entry, action: :update
      define :publish_changelog_entry, action: :publish
      define :list_published_changelog, action: :published
    end
  end
end
```

- [ ] **Step 8: Register domain in config**

In `config/config.exs`, add `FounderPad.Content` to the `ash_domains` list:

```elixir
config :founder_pad,
  ash_domains: [
    FounderPad.Accounts,
    FounderPad.Billing,
    FounderPad.AI,
    FounderPad.Notifications,
    FounderPad.Audit,
    FounderPad.FeatureFlags,
    FounderPad.Webhooks,
    FounderPad.Analytics,
    FounderPad.Content
  ]
```

- [ ] **Step 9: Generate and run migration**

Run:
```bash
mix ash.codegen create_content_tables
mix ecto.migrate
```

- [ ] **Step 10: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles cleanly.

- [ ] **Step 11: Commit**

```bash
git add lib/founder_pad/content/ config/config.exs priv/repo/migrations/*content*
git commit -m "feat(content): add Content domain with Post, Category, Tag, ChangelogEntry resources"
```

---

## Task 4: Content Domain Unit Tests

**Files:**
- Create: `test/founder_pad/content/post_test.exs`
- Create: `test/founder_pad/content/category_test.exs`
- Create: `test/founder_pad/content/changelog_entry_test.exs`
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Add content factories**

Add to `test/support/factory.ex`:

```elixir
def create_category!(attrs \\ %{}) do
  admin = Map.get_lazy(attrs, :actor, fn -> create_admin_user!() end)

  FounderPad.Content.Category
  |> Ash.Changeset.for_create(:create, %{
    name: Map.get(attrs, :name, "Category #{System.unique_integer([:positive])}"),
    slug: Map.get(attrs, :slug, nil),
    description: Map.get(attrs, :description, "A test category")
  }, actor: admin)
  |> Ash.create!()
end

def create_tag!(attrs \\ %{}) do
  admin = Map.get_lazy(attrs, :actor, fn -> create_admin_user!() end)

  FounderPad.Content.Tag
  |> Ash.Changeset.for_create(:create, %{
    name: Map.get(attrs, :name, "Tag #{System.unique_integer([:positive])}"),
    slug: Map.get(attrs, :slug, nil)
  }, actor: admin)
  |> Ash.create!()
end

def create_post!(attrs \\ %{}) do
  admin = Map.get_lazy(attrs, :actor, fn -> create_admin_user!() end)

  FounderPad.Content.Post
  |> Ash.Changeset.for_create(:create, %{
    title: Map.get(attrs, :title, "Test Post #{System.unique_integer([:positive])}"),
    slug: Map.get(attrs, :slug, nil),
    body: Map.get(attrs, :body, "<p>Test post content with enough words.</p>"),
    excerpt: Map.get(attrs, :excerpt, "Test excerpt"),
    status: Map.get(attrs, :status, :draft),
    published_at: Map.get(attrs, :published_at, nil),
    author_id: admin.id
  }, actor: admin)
  |> Ash.create!()
end

def create_published_post!(attrs \\ %{}) do
  admin = Map.get_lazy(attrs, :actor, fn -> create_admin_user!() end)

  post = create_post!(Map.put(attrs, :actor, admin))

  post
  |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
  |> Ash.update!()
end

def create_changelog_entry!(attrs \\ %{}) do
  admin = Map.get_lazy(attrs, :actor, fn -> create_admin_user!() end)

  FounderPad.Content.ChangelogEntry
  |> Ash.Changeset.for_create(:create, %{
    version: Map.get(attrs, :version, "v#{System.unique_integer([:positive])}.0.0"),
    title: Map.get(attrs, :title, "Release #{System.unique_integer([:positive])}"),
    body: Map.get(attrs, :body, "<p>Release notes</p>"),
    type: Map.get(attrs, :type, :feature),
    author_id: admin.id
  }, actor: admin)
  |> Ash.create!()
end
```

- [ ] **Step 2: Write post unit tests**

Create `test/founder_pad/content/post_test.exs`:

```elixir
defmodule FounderPad.Content.PostTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  describe "create post" do
    test "creates draft post with auto-generated slug" do
      admin = create_admin_user!()

      assert {:ok, post} =
        FounderPad.Content.Post
        |> Ash.Changeset.for_create(:create, %{
          title: "My First Blog Post",
          body: "<p>Hello world</p>",
          excerpt: "A test",
          author_id: admin.id
        }, actor: admin)
        |> Ash.create()

      assert post.slug == "my-first-blog-post"
      assert post.status == :draft
      assert post.reading_time_minutes == 1
    end

    test "rejects creation by non-admin" do
      user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
        FounderPad.Content.Post
        |> Ash.Changeset.for_create(:create, %{
          title: "Should Fail",
          body: "<p>No</p>",
          author_id: user.id
        }, actor: user)
        |> Ash.create()
    end
  end

  describe "publish post" do
    test "sets status to published with timestamp" do
      admin = create_admin_user!()
      post = create_post!(%{actor: admin})

      assert post.status == :draft

      {:ok, published} =
        post
        |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
        |> Ash.update()

      assert published.status == :published
      assert published.published_at
    end
  end

  describe "published read" do
    test "returns only published posts" do
      admin = create_admin_user!()
      _draft = create_post!(%{actor: admin})
      published = create_published_post!(%{actor: admin})

      posts =
        FounderPad.Content.Post
        |> Ash.Query.for_read(:published)
        |> Ash.read!()

      assert length(posts) == 1
      assert hd(posts).id == published.id
    end
  end
end
```

- [ ] **Step 3: Write category and changelog tests**

Create `test/founder_pad/content/category_test.exs`:

```elixir
defmodule FounderPad.Content.CategoryTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  test "creates category with auto-generated slug" do
    admin = create_admin_user!()

    {:ok, cat} =
      FounderPad.Content.Category
      |> Ash.Changeset.for_create(:create, %{
        name: "Getting Started",
        description: "Beginner guides"
      }, actor: admin)
      |> Ash.create()

    assert cat.slug == "getting-started"
  end

  test "enforces unique slug" do
    admin = create_admin_user!()
    create_category!(%{slug: "unique-slug", actor: admin})

    assert {:error, _} =
      FounderPad.Content.Category
      |> Ash.Changeset.for_create(:create, %{name: "Another", slug: "unique-slug"}, actor: admin)
      |> Ash.create()
  end
end
```

Create `test/founder_pad/content/changelog_entry_test.exs`:

```elixir
defmodule FounderPad.Content.ChangelogEntryTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  test "creates and publishes changelog entry" do
    admin = create_admin_user!()
    entry = create_changelog_entry!(%{actor: admin})

    assert entry.status == :draft

    {:ok, published} =
      entry
      |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
      |> Ash.update()

    assert published.status == :published
    assert published.published_at
  end

  test "published read returns only published entries" do
    admin = create_admin_user!()
    _draft = create_changelog_entry!(%{actor: admin})

    published = create_changelog_entry!(%{actor: admin})
    published
    |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
    |> Ash.update!()

    entries =
      FounderPad.Content.ChangelogEntry
      |> Ash.Query.for_read(:published)
      |> Ash.read!()

    assert length(entries) == 1
  end
end
```

- [ ] **Step 4: Run all content tests**

Run: `mix test test/founder_pad/content/`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add test/founder_pad/content/ test/support/factory.ex
git commit -m "test(content): add unit tests for Post, Category, ChangelogEntry resources"
```

---

## Task 5: SEO Scorer

**Files:**
- Create: `lib/founder_pad/content/seo_scorer.ex`
- Create: `test/founder_pad/content/seo_scorer_test.exs`

- [ ] **Step 1: Write failing test**

Create `test/founder_pad/content/seo_scorer_test.exs`:

```elixir
defmodule FounderPad.Content.SeoScorerTest do
  use ExUnit.Case, async: true

  alias FounderPad.Content.SeoScorer

  describe "score/1" do
    test "perfect score for well-optimized post" do
      post = %{
        title: "A Perfect Title That Is Good Length",
        meta_description: String.duplicate("a", 130),
        excerpt: "Has an excerpt",
        featured_image_url: "/uploads/blog/image.jpg",
        canonical_url: "https://example.com/blog/post",
        slug: "perfect-post",
        body: String.duplicate("word ", 100),
        og_image_url: "/uploads/blog/og.jpg"
      }

      result = SeoScorer.score(post)
      assert result.score == 100
      assert Enum.all?(result.checks, fn {_name, pass} -> pass end)
    end

    test "low score for empty post" do
      post = %{
        title: "Hi",
        meta_description: nil,
        excerpt: nil,
        featured_image_url: nil,
        canonical_url: nil,
        slug: "hi",
        body: nil,
        og_image_url: nil
      }

      result = SeoScorer.score(post)
      assert result.score < 50
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/founder_pad/content/seo_scorer_test.exs`
Expected: FAIL

- [ ] **Step 3: Implement SeoScorer**

Create `lib/founder_pad/content/seo_scorer.ex`:

```elixir
defmodule FounderPad.Content.SeoScorer do
  @moduledoc "Calculates an SEO completeness score for a blog post."

  @doc "Returns %{score: 0..100, checks: [{name, pass?}]}"
  def score(post) do
    checks = [
      {:title_length, check_title_length(post)},
      {:meta_description, check_meta_description(post)},
      {:has_excerpt, check_excerpt(post)},
      {:has_featured_image, not is_nil(access(post, :featured_image_url))},
      {:has_canonical_url, not is_nil(access(post, :canonical_url))},
      {:slug_is_clean, check_slug(post)},
      {:body_length, check_body_length(post)},
      {:has_og_image, not is_nil(access(post, :og_image_url))}
    ]

    passed = Enum.count(checks, fn {_, pass} -> pass end)
    %{score: round(passed / length(checks) * 100), checks: checks}
  end

  defp check_title_length(post) do
    title = access(post, :title) || ""
    len = String.length(title)
    len >= 20 and len <= 70
  end

  defp check_meta_description(post) do
    desc = access(post, :meta_description)
    not is_nil(desc) and String.length(desc) >= 50 and String.length(desc) <= 160
  end

  defp check_excerpt(post) do
    excerpt = access(post, :excerpt)
    not is_nil(excerpt) and excerpt != ""
  end

  defp check_slug(post) do
    slug = access(post, :slug) || ""
    Regex.match?(~r/^[a-z0-9\-]+$/, slug)
  end

  defp check_body_length(post) do
    body = access(post, :body) || ""
    word_count = body |> String.replace(~r/<[^>]+>/, " ") |> String.split(~r/\s+/, trim: true) |> length()
    word_count >= 50
  end

  defp access(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
```

- [ ] **Step 4: Run tests**

Run: `mix test test/founder_pad/content/seo_scorer_test.exs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/founder_pad/content/seo_scorer.ex test/founder_pad/content/seo_scorer_test.exs
git commit -m "feat(content): add SEO scorer for blog post completeness checks"
```

---

## Task 6: RequireAdmin Hook + Admin Routes

**Files:**
- Create: `lib/founder_pad_web/hooks/require_admin.ex`
- Modify: `lib/founder_pad_web/router.ex`

- [ ] **Step 1: Create RequireAdmin hook**

Create `lib/founder_pad_web/hooks/require_admin.ex`:

```elixir
defmodule FounderPadWeb.Hooks.RequireAdmin do
  @moduledoc "LiveView on_mount hook that redirects non-admin users."
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_navigate: 2]

  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && user.is_admin do
      {:cont, assign(socket, admin_user: user)}
    else
      {:halt, push_navigate(socket, to: "/dashboard")}
    end
  end
end
```

- [ ] **Step 2: Add all routes to router**

In `lib/founder_pad_web/router.ex`, add the following routes:

**After the existing public scope, add blog public routes:**
```elixir
# Public blog routes
scope "/blog", FounderPadWeb.Blog do
  pipe_through :browser

  live "/", BlogIndexLive
  live "/category/:slug", BlogCategoryLive
  live "/tag/:slug", BlogTagLive
  live "/:slug", BlogPostLive
end
```

**Add RSS feed routes (controller, not LiveView):**
```elixir
scope "/", FounderPadWeb do
  pipe_through :browser

  get "/blog/feed.xml", FeedController, :blog_feed
  get "/changelog/feed.xml", FeedController, :changelog_feed
end
```

**Add admin live_session after the `:app` live_session:**
```elixir
live_session :admin,
  layout: {FounderPadWeb.Layouts, :app},
  on_mount: [
    {FounderPadWeb.Hooks.AssignDefaults, :default},
    {FounderPadWeb.Hooks.RequireAuth, :default},
    {FounderPadWeb.Hooks.RequireAdmin, :default}
  ] do
  scope "/admin", FounderPadWeb.Admin do
    pipe_through :browser

    live "/blog", BlogListLive
    live "/blog/new", BlogEditorLive
    live "/blog/:id/edit", BlogEditorLive
    live "/blog/categories", BlogCategoriesLive
    live "/blog/tags", BlogTagsLive
    live "/changelog", ChangelogListLive
    live "/changelog/new", ChangelogEditorLive
    live "/changelog/:id/edit", ChangelogEditorLive
    live "/seo", SeoDashboardLive
  end
end
```

- [ ] **Step 3: Verify compilation**

Run: `mix compile`
Expected: Will warn about missing LiveView modules — that's expected, we'll create them next.

- [ ] **Step 4: Commit**

```bash
git add lib/founder_pad_web/hooks/require_admin.ex lib/founder_pad_web/router.ex
git commit -m "feat(content): add RequireAdmin hook and blog/admin routes"
```

---

## Task 7: Tiptap WYSIWYG Editor Hook

**Files:**
- Create: `assets/js/hooks/tiptap_editor.js`
- Modify: `assets/js/app.js`
- Modify: `assets/package.json` (via npm install)

- [ ] **Step 1: Install Tiptap npm packages**

Run:
```bash
cd /Users/kojo/Desktop/boilerplate/assets && npm install @tiptap/core @tiptap/starter-kit @tiptap/extension-image @tiptap/extension-link @tiptap/extension-placeholder
```

- [ ] **Step 2: Create TiptapEditor hook**

Create `assets/js/hooks/tiptap_editor.js`:

```javascript
import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Image from '@tiptap/extension-image'
import Link from '@tiptap/extension-link'
import Placeholder from '@tiptap/extension-placeholder'

const TiptapEditor = {
  mounted() {
    const textarea = this.el.querySelector('textarea[data-tiptap-target]')
    const editorContainer = this.el.querySelector('[data-tiptap-editor]')

    if (!textarea || !editorContainer) return

    this.editor = new Editor({
      element: editorContainer,
      extensions: [
        StarterKit,
        Image,
        Link.configure({ openOnClick: false }),
        Placeholder.configure({
          placeholder: 'Start writing your post...'
        })
      ],
      content: textarea.value || '',
      editorProps: {
        attributes: {
          class: 'prose prose-sm max-w-none focus:outline-none min-h-[300px] p-4'
        }
      },
      onUpdate: ({ editor }) => {
        textarea.value = editor.getHTML()
        textarea.dispatchEvent(new Event('input', { bubbles: true }))
      }
    })

    // Handle image uploads from LiveView
    this.handleEvent('insert-image', ({ url }) => {
      this.editor.chain().focus().setImage({ src: url }).run()
    })

    // Toolbar button handlers
    this.el.querySelectorAll('[data-tiptap-action]').forEach(button => {
      button.addEventListener('click', (e) => {
        e.preventDefault()
        const action = button.dataset.tiptapAction
        this.handleToolbarAction(action)
      })
    })
  },

  handleToolbarAction(action) {
    const chain = this.editor.chain().focus()

    switch (action) {
      case 'bold': chain.toggleBold().run(); break
      case 'italic': chain.toggleItalic().run(); break
      case 'strike': chain.toggleStrike().run(); break
      case 'code': chain.toggleCode().run(); break
      case 'h2': chain.toggleHeading({ level: 2 }).run(); break
      case 'h3': chain.toggleHeading({ level: 3 }).run(); break
      case 'bullet-list': chain.toggleBulletList().run(); break
      case 'ordered-list': chain.toggleOrderedList().run(); break
      case 'blockquote': chain.toggleBlockquote().run(); break
      case 'code-block': chain.toggleCodeBlock().run(); break
      case 'horizontal-rule': chain.setHorizontalRule().run(); break
      case 'link':
        const url = prompt('Enter URL:')
        if (url) chain.setLink({ href: url }).run()
        break
      case 'undo': chain.undo().run(); break
      case 'redo': chain.redo().run(); break
    }
  },

  destroyed() {
    if (this.editor) this.editor.destroy()
  }
}

export default TiptapEditor
```

- [ ] **Step 3: Register hook in app.js**

In `assets/js/app.js`, add the import and register the hook:

```javascript
import TiptapEditor from "./hooks/tiptap_editor"
```

And add `TiptapEditor` to the hooks object:
```javascript
hooks: {ThemeToggle, Analytics, ScrollReveal, AutoDismiss, ThemeSettings, TiptapEditor},
```

- [ ] **Step 4: Verify assets compile**

Run:
```bash
cd /Users/kojo/Desktop/boilerplate && mix assets.build
```
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add assets/js/hooks/tiptap_editor.js assets/js/app.js assets/package.json assets/package-lock.json
git commit -m "feat(content): add Tiptap WYSIWYG editor LiveView hook"
```

---

## Task 8: SEO Components

**Files:**
- Create: `lib/founder_pad_web/components/seo_components.ex`

- [ ] **Step 1: Create SEO function components**

Create `lib/founder_pad_web/components/seo_components.ex`:

```elixir
defmodule FounderPadWeb.SeoComponents do
  @moduledoc "Function components for SEO meta tags and structured data."
  use Phoenix.Component

  @doc "Renders Open Graph and Twitter meta tags."
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :image, :string, default: nil
  attr :url, :string, default: nil
  attr :type, :string, default: "website"

  def og_meta(assigns) do
    ~H"""
    <meta :if={@title} property="og:title" content={@title} />
    <meta :if={@description} property="og:description" content={@description} />
    <meta :if={@image} property="og:image" content={@image} />
    <meta :if={@url} property="og:url" content={@url} />
    <meta property="og:type" content={@type} />
    <meta :if={@title} name="twitter:card" content="summary_large_image" />
    <meta :if={@title} name="twitter:title" content={@title} />
    <meta :if={@description} name="twitter:description" content={@description} />
    <meta :if={@image} name="twitter:image" content={@image} />
    """
  end

  @doc "Renders JSON-LD Article structured data."
  attr :post, :map, required: true
  attr :author, :map, required: true
  attr :site_url, :string, required: true

  def article_json_ld(assigns) do
    json =
      Jason.encode!(%{
        "@context" => "https://schema.org",
        "@type" => "Article",
        "headline" => assigns.post.meta_title || assigns.post.title,
        "description" => assigns.post.meta_description || assigns.post.excerpt,
        "image" => assigns.post.og_image_url || assigns.post.featured_image_url,
        "author" => %{"@type" => "Person", "name" => assigns.author.name || assigns.author.email},
        "datePublished" => to_string(assigns.post.published_at),
        "dateModified" => to_string(assigns.post.updated_at),
        "publisher" => %{
          "@type" => "Organization",
          "name" => "FounderPad"
        }
      })

    assigns = assign(assigns, :json, json)

    ~H"""
    <script type="application/ld+json">
      {raw(@json)}
    </script>
    """
  end

  @doc "Renders canonical URL link tag."
  attr :url, :string, required: true

  def canonical(assigns) do
    ~H"""
    <link rel="canonical" href={@url} />
    """
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add lib/founder_pad_web/components/seo_components.ex
git commit -m "feat(content): add SEO function components for meta tags and JSON-LD"
```

---

## Task 9: Blog Components

**Files:**
- Create: `lib/founder_pad_web/components/blog_components.ex`

- [ ] **Step 1: Create blog function components**

Create `lib/founder_pad_web/components/blog_components.ex`:

```elixir
defmodule FounderPadWeb.BlogComponents do
  @moduledoc "Reusable function components for blog UI."
  use Phoenix.Component

  attr :post, :map, required: true

  def blog_card(assigns) do
    ~H"""
    <article class="group bg-white rounded-2xl border border-neutral-200/60 overflow-hidden hover:shadow-lg transition-all duration-300">
      <a href={"/blog/#{@post.slug}"} class="block">
        <div :if={@post.featured_image_url} class="aspect-[16/9] overflow-hidden">
          <img
            src={@post.featured_image_url}
            alt={@post.title}
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
          />
        </div>
        <div :if={!@post.featured_image_url} class="aspect-[16/9] bg-gradient-to-br from-primary/5 to-primary/10 flex items-center justify-center">
          <span class="material-symbols-outlined text-4xl text-primary/30">article</span>
        </div>
        <div class="p-6">
          <div class="flex items-center gap-2 mb-3">
            <.category_badge :for={cat <- (@post.categories || [])} category={cat} />
          </div>
          <h3 class="font-heading text-lg font-semibold text-on-surface mb-2 group-hover:text-primary transition-colors">
            {@post.title}
          </h3>
          <p :if={@post.excerpt} class="text-on-surface-variant text-sm line-clamp-2 mb-4">
            {@post.excerpt}
          </p>
          <.post_meta post={@post} />
        </div>
      </a>
    </article>
    """
  end

  attr :post, :map, required: true

  def post_meta(assigns) do
    ~H"""
    <div class="flex items-center gap-3 text-xs text-on-surface-variant">
      <span :if={@post.author} class="flex items-center gap-1.5">
        <span class="material-symbols-outlined text-sm">person</span>
        {@post.author.name || @post.author.email}
      </span>
      <span :if={@post.published_at} class="flex items-center gap-1.5">
        <span class="material-symbols-outlined text-sm">calendar_today</span>
        {Calendar.strftime(@post.published_at, "%b %d, %Y")}
      </span>
      <span class="flex items-center gap-1.5">
        <span class="material-symbols-outlined text-sm">schedule</span>
        {@post.reading_time_minutes} min read
      </span>
    </div>
    """
  end

  attr :category, :map, required: true

  def category_badge(assigns) do
    ~H"""
    <a
      href={"/blog/category/#{@category.slug}"}
      class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary/10 text-primary hover:bg-primary/20 transition-colors"
    >
      {@category.name}
    </a>
    """
  end

  attr :tag, :map, required: true

  def tag_badge(assigns) do
    ~H"""
    <a
      href={"/blog/tag/#{@tag.slug}"}
      class="inline-flex items-center px-2 py-0.5 rounded-md text-xs text-on-surface-variant border border-neutral-200 hover:border-primary hover:text-primary transition-colors"
    >
      #<%= @tag.name %>
    </a>
    """
  end

  attr :score, :integer, required: true

  def seo_score_badge(assigns) do
    color =
      cond do
        assigns.score >= 80 -> "bg-green-100 text-green-700"
        assigns.score >= 50 -> "bg-amber-100 text-amber-700"
        true -> "bg-red-100 text-red-700"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{@color}"}>
      SEO: {@score}%
    </span>
    """
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add lib/founder_pad_web/components/blog_components.ex
git commit -m "feat(content): add blog function components (cards, badges, meta)"
```

---

## Task 10: Public Blog LiveViews

**Files:**
- Create: `lib/founder_pad_web/live/blog/blog_index_live.ex`
- Create: `lib/founder_pad_web/live/blog/blog_post_live.ex`
- Create: `lib/founder_pad_web/live/blog/blog_category_live.ex`
- Create: `lib/founder_pad_web/live/blog/blog_tag_live.ex`
- Create: `test/founder_pad_web/live/blog/blog_index_live_test.exs`
- Create: `test/founder_pad_web/live/blog/blog_post_live_test.exs`

This task is large — the full LiveView implementations with templates, event handlers, and tests. Each LiveView follows the pattern from existing DocsLive (layout: false, standalone public page).

The actual implementation of these LiveViews will be done following the existing ChangelogLive pattern — `mount/3` queries the database, `render/1` provides the HEEx template. Given the size of these files (each is 100-300 lines of HEEx), implementation details are best handled by the executing agent with the design spec as reference.

- [ ] **Step 1: Create BlogIndexLive**

Create `lib/founder_pad_web/live/blog/blog_index_live.ex` — paginated listing of published posts with category filter sidebar, using `BlogComponents.blog_card/1`. Mount queries `Content.list_published_posts()`. Layout: false (standalone public page matching docs styling).

- [ ] **Step 2: Create BlogPostLive**

Create `lib/founder_pad_web/live/blog/blog_post_live.ex` — single post page. Mount queries `Content.get_post_by_slug(slug)`. Renders post body as raw HTML, author info, categories, tags. Includes `SeoComponents.og_meta/1`, `SeoComponents.article_json_ld/1`, and `SeoComponents.canonical/1` in the head.

- [ ] **Step 3: Create BlogCategoryLive and BlogTagLive**

Filtered post listings — same layout as BlogIndexLive but filtered by category/tag slug.

- [ ] **Step 4: Write LiveView tests**

Create `test/founder_pad_web/live/blog/blog_index_live_test.exs` and `blog_post_live_test.exs` testing: published posts appear, drafts don't, 404 for bad slugs.

- [ ] **Step 5: Run tests**

Run: `mix test test/founder_pad_web/live/blog/`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/founder_pad_web/live/blog/ test/founder_pad_web/live/blog/
git commit -m "feat(content): add public blog LiveViews (index, post, category, tag)"
```

---

## Task 11: Admin Blog LiveViews

**Files:**
- Create: `lib/founder_pad_web/live/admin/blog_list_live.ex`
- Create: `lib/founder_pad_web/live/admin/blog_editor_live.ex`
- Create: `lib/founder_pad_web/live/admin/blog_categories_live.ex`
- Create: `lib/founder_pad_web/live/admin/blog_tags_live.ex`
- Create: `test/founder_pad_web/live/admin/blog_list_live_test.exs`
- Create: `test/founder_pad_web/live/admin/blog_editor_live_test.exs`

- [ ] **Step 1: Create BlogListLive**

Admin post list with status filter tabs, search, quick actions (edit, publish, archive, delete). Table view showing title, status badge, author, published_at, SEO score badge.

- [ ] **Step 2: Create BlogEditorLive**

The most complex component. Form with: title, slug (auto-generated, editable), excerpt, status selector, category multi-select, tag multi-select. Tiptap editor via `phx-hook="TiptapEditor"`. Featured image upload via `allow_upload/3`. SEO fields panel (meta_title, meta_description, og_image, canonical_url). SEO score display. Preview toggle. Handles both `:new` and `:id/edit` routes.

- [ ] **Step 3: Create BlogCategoriesLive and BlogTagsLive**

Simple admin CRUD lists with inline create/edit forms.

- [ ] **Step 4: Write admin LiveView tests**

Test admin access control (non-admin redirected), CRUD operations, publish flow.

- [ ] **Step 5: Run tests**

Run: `mix test test/founder_pad_web/live/admin/`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/founder_pad_web/live/admin/ test/founder_pad_web/live/admin/
git commit -m "feat(content): add admin blog LiveViews (list, editor, categories, tags)"
```

---

## Task 12: Admin Changelog LiveViews + Refactor Public Changelog

**Files:**
- Create: `lib/founder_pad_web/live/admin/changelog_list_live.ex`
- Create: `lib/founder_pad_web/live/admin/changelog_editor_live.ex`
- Modify: `lib/founder_pad_web/live/docs/changelog_live.ex`
- Create: `test/founder_pad_web/live/admin/changelog_list_live_test.exs`

- [ ] **Step 1: Create admin ChangelogListLive**

Table of all changelog entries with status, version, type badges, quick publish action.

- [ ] **Step 2: Create admin ChangelogEditorLive**

Form with version, title, body (Tiptap editor), type selector (feature/fix/improvement/breaking).

- [ ] **Step 3: Refactor public ChangelogLive to DB-backed**

In `lib/founder_pad_web/live/docs/changelog_live.ex`:
- Remove the `@releases` module attribute with hardcoded data
- Replace `mount/3` to query `FounderPad.Content.list_published_changelog()`
- Keep the same UI/template structure, just change data source
- Keep the expand/collapse toggle behavior

- [ ] **Step 4: Write tests**

Test admin CRUD and public changelog showing only published entries.

- [ ] **Step 5: Commit**

```bash
git add lib/founder_pad_web/live/admin/changelog_* lib/founder_pad_web/live/docs/changelog_live.ex test/founder_pad_web/live/admin/changelog_*
git commit -m "feat(content): add admin changelog CRUD, refactor public changelog to DB-backed"
```

---

## Task 13: RSS Feed Controller + Sitemap Extension

**Files:**
- Create: `lib/founder_pad_web/controllers/feed_controller.ex`
- Create: `test/founder_pad_web/controllers/feed_controller_test.exs`
- Modify: `lib/founder_pad_web/controllers/sitemap_controller.ex`

- [ ] **Step 1: Create FeedController**

Create `lib/founder_pad_web/controllers/feed_controller.ex`:

```elixir
defmodule FounderPadWeb.FeedController do
  use FounderPadWeb, :controller

  def blog_feed(conn, _params) do
    posts =
      FounderPad.Content.Post
      |> Ash.Query.for_read(:published)
      |> Ash.Query.load([:author])
      |> Ash.Query.limit(20)
      |> Ash.read!()

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, render_rss("FounderPad Blog", "/blog", posts, :blog))
  end

  def changelog_feed(conn, _params) do
    entries =
      FounderPad.Content.ChangelogEntry
      |> Ash.Query.for_read(:published)
      |> Ash.Query.limit(20)
      |> Ash.read!()

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, render_rss("FounderPad Changelog", "/changelog", entries, :changelog))
  end

  defp render_rss(title, path, items, type) do
    host = FounderPadWeb.Endpoint.url()

    items_xml =
      Enum.map_join(items, "\n", fn item ->
        case type do
          :blog ->
            """
            <item>
              <title><![CDATA[#{item.title}]]></title>
              <link>#{host}/blog/#{item.slug}</link>
              <description><![CDATA[#{item.excerpt || ""}]]></description>
              <pubDate>#{format_rfc822(item.published_at)}</pubDate>
              <guid>#{host}/blog/#{item.slug}</guid>
            </item>
            """

          :changelog ->
            """
            <item>
              <title><![CDATA[#{item.version}: #{item.title}]]></title>
              <link>#{host}/changelog</link>
              <description><![CDATA[#{item.body || ""}]]></description>
              <pubDate>#{format_rfc822(item.published_at)}</pubDate>
              <guid>#{host}/changelog/#{item.id}</guid>
            </item>
            """
        end
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
      <channel>
        <title>#{title}</title>
        <link>#{host}#{path}</link>
        <description>#{title} feed</description>
        <atom:link href="#{host}#{path}/feed.xml" rel="self" type="application/rss+xml"/>
        #{items_xml}
      </channel>
    </rss>
    """
  end

  defp format_rfc822(nil), do: ""

  defp format_rfc822(datetime) do
    Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S +0000")
  end
end
```

- [ ] **Step 2: Extend SitemapController**

In `lib/founder_pad_web/controllers/sitemap_controller.ex`, update `index/2` to include blog posts:

```elixir
def index(conn, _params) do
  host = FounderPadWeb.Endpoint.url()

  static_urls = [
    %{loc: host, changefreq: "weekly", priority: "1.0"},
    %{loc: "#{host}/auth/login", changefreq: "monthly", priority: "0.8"},
    %{loc: "#{host}/auth/register", changefreq: "monthly", priority: "0.8"},
    %{loc: "#{host}/blog", changefreq: "daily", priority: "0.9"},
    %{loc: "#{host}/changelog", changefreq: "weekly", priority: "0.7"},
    %{loc: "#{host}/docs", changefreq: "monthly", priority: "0.6"}
  ]

  blog_urls =
    FounderPad.Content.Post
    |> Ash.Query.for_read(:published)
    |> Ash.read!()
    |> Enum.map(fn post ->
      %{loc: "#{host}/blog/#{post.slug}", changefreq: "weekly", priority: "0.7"}
    end)

  all_urls = static_urls ++ blog_urls

  conn
  |> put_resp_content_type("application/xml")
  |> send_resp(200, render_sitemap(all_urls))
end
```

- [ ] **Step 3: Write feed controller test**

Create `test/founder_pad_web/controllers/feed_controller_test.exs`:

```elixir
defmodule FounderPadWeb.FeedControllerTest do
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  test "GET /blog/feed.xml returns RSS with published posts", %{conn: conn} do
    admin = create_admin_user!()
    create_published_post!(%{title: "Test RSS Post", actor: admin})

    conn = get(conn, "/blog/feed.xml")
    assert response_content_type(conn, :xml)
    body = response(conn, 200)
    assert body =~ "Test RSS Post"
    assert body =~ "<rss version=\"2.0\""
  end

  test "GET /changelog/feed.xml returns RSS with published entries", %{conn: conn} do
    admin = create_admin_user!()
    entry = create_changelog_entry!(%{title: "New Feature", actor: admin})

    entry
    |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
    |> Ash.update!()

    conn = get(conn, "/changelog/feed.xml")
    assert response_content_type(conn, :xml)
    body = response(conn, 200)
    assert body =~ "New Feature"
  end
end
```

- [ ] **Step 4: Run tests**

Run: `mix test test/founder_pad_web/controllers/feed_controller_test.exs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/founder_pad_web/controllers/feed_controller.ex lib/founder_pad_web/controllers/sitemap_controller.ex test/founder_pad_web/controllers/feed_controller_test.exs
git commit -m "feat(content): add RSS feed controller and extend sitemap with blog URLs"
```

---

## Task 14: Oban Scheduled Publishing Worker

**Files:**
- Create: `lib/founder_pad/content/workers/publish_scheduled_posts_worker.ex`
- Modify: `config/config.exs`

- [ ] **Step 1: Create worker**

Create `lib/founder_pad/content/workers/publish_scheduled_posts_worker.ex`:

```elixir
defmodule FounderPad.Content.Workers.PublishScheduledPostsWorker do
  @moduledoc "Oban cron worker that publishes scheduled posts when their scheduled_at time has passed."
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(_job) do
    FounderPad.Content.Post
    |> Ash.Query.for_read(:scheduled_ready)
    |> Ash.read!()
    |> Enum.each(fn post ->
      post
      |> Ash.Changeset.for_update(:publish, %{})
      |> Ash.update!()
    end)

    :ok
  end
end
```

- [ ] **Step 2: Add Oban cron config**

In `config/config.exs`, update the Oban config to add the cron plugin:

```elixir
config :founder_pad, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, mailers: 20, billing: 5, ai: 3],
  repo: FounderPad.Repo,
  plugins: [
    {Oban.Plugins.Cron, crontab: [
      {"*/5 * * * *", FounderPad.Content.Workers.PublishScheduledPostsWorker}
    ]}
  ]
```

- [ ] **Step 3: Commit**

```bash
git add lib/founder_pad/content/workers/ config/config.exs
git commit -m "feat(content): add Oban cron worker for publishing scheduled posts"
```

---

## Task 15: SEO Dashboard + Admin Nav + Final Integration

**Files:**
- Create: `lib/founder_pad_web/live/admin/seo_dashboard_live.ex`
- Modify: `lib/founder_pad_web/components/layouts/app.html.heex`
- Modify: `lib/founder_pad_web/components/layouts/root.html.heex`

- [ ] **Step 1: Create SEO Dashboard LiveView**

Admin page showing: top keywords from existing SearchConsoleData, per-post SEO scores, links to Plausible. Queries `FounderPad.Analytics.SearchConsoleData` and all posts with their SEO scores.

- [ ] **Step 2: Add admin nav links to sidebar**

In `app.html.heex`, add a "Content" section to the sidebar nav for admin users:

```heex
<%= if @current_user && @current_user.is_admin do %>
  <div class="mt-6 pt-4 border-t border-neutral-200/60">
    <p class="px-3 mb-2 text-[10px] font-semibold uppercase tracking-wider text-on-surface-variant/50">Admin</p>
    <.nav_link href="/admin/blog" icon="edit_note" label="Blog" active={@active_nav == :admin_blog} />
    <.nav_link href="/admin/changelog" icon="new_releases" label="Changelog" active={@active_nav == :admin_changelog} />
    <.nav_link href="/admin/seo" icon="search" label="SEO" active={@active_nav == :admin_seo} />
  </div>
<% end %>
```

- [ ] **Step 3: Add SEO meta tags to root layout**

In `root.html.heex`, add inside `<head>` after existing meta tags:

```heex
<meta :if={assigns[:page_description]} name="description" content={@page_description} />
<.og_meta
  :if={assigns[:page_description]}
  title={assigns[:page_title]}
  description={assigns[:page_description]}
  image={assigns[:page_image]}
  url={assigns[:page_url]}
  type={assigns[:page_type] || "website"}
/>
<.canonical :if={assigns[:canonical_url]} url={@canonical_url} />
```

(Import `SeoComponents` in the layouts module.)

- [ ] **Step 4: Run full test suite**

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 5: Final commit**

```bash
git add lib/founder_pad_web/live/admin/seo_dashboard_live.ex lib/founder_pad_web/components/layouts/
git commit -m "feat(content): add SEO dashboard, admin nav links, meta tag integration"
```

---

## Verification

After all tasks are complete:

1. **Tests:** `mix test` — all pass
2. **Lint:** `mix credo` — no new warnings
3. **Manual testing:**
   - Start server: `PORT=4004 mix phx.server`
   - Visit `/blog` — should show published posts (empty initially)
   - Visit `/admin/blog` — admin CMS (requires is_admin user)
   - Create a post in admin, publish it, verify it appears at `/blog/:slug`
   - Visit `/blog/feed.xml` — RSS feed with published posts
   - Visit `/sitemap.xml` — includes blog post URLs
   - Visit `/changelog` — DB-backed changelog (empty initially)
   - View page source on blog post — check meta tags, JSON-LD, canonical URL
4. **SEO check:** Use browser dev tools to verify Open Graph tags render correctly
