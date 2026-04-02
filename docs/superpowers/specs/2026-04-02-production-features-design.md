# FounderPad Production Features Design Spec

## Context

FounderPad is a SaaS boilerplate with 20 Ash resources, 16 LiveViews, Stripe billing, AI agents, team management, and more. However, it lacks several features expected of a production-ready SaaS product: a blog/CMS, comprehensive SEO, admin panel, API key management, OAuth/SSO, GDPR compliance, transactional email templates, help center, and polished error pages.

This spec covers all 10 missing features, organized into 4 sub-projects built sequentially. Each sub-project is independently deployable and testable.

---

## Sub-project 1: Content Engine (Blog CMS + SEO + Changelog)

### New Domain: `FounderPad.Content`

Blog content is **global** (not org-scoped) — it's marketing/product content authored by admins. This mirrors how existing `/docs` pages work.

### Resources

**`Content.Post`** (table: `blog_posts`)
- `id` (uuid), `title` (string, required), `slug` (string, unique), `body` (string, HTML from Tiptap), `excerpt` (string), `featured_image_url` (string), `status` (atom: draft/published/scheduled/archived, default: draft), `published_at` (utc_datetime), `scheduled_at` (utc_datetime)
- SEO fields: `meta_title`, `meta_description`, `og_image_url`, `canonical_url`
- Computed: `reading_time_minutes` (integer)
- Relationships: `belongs_to :author` (User), `many_to_many :categories` (through PostCategory), `many_to_many :tags` (through PostTag)
- Actions: `:create`, `:update`, `:publish` (sets status + published_at), `:schedule` (sets scheduled_at), `:archive`, `:published` (read: public published posts), `:by_slug` (get_by), `:by_category`, `:by_tag`, `:scheduled_ready` (for Oban)

**`Content.Category`** (table: `blog_categories`)
- `id`, `name`, `slug` (unique), `description`, timestamps
- Relationships: `many_to_many :posts`

**`Content.Tag`** (table: `blog_tags`)
- `id`, `name`, `slug` (unique), timestamps
- Relationships: `many_to_many :posts`

**`Content.PostCategory`** (join table: `blog_post_categories`)
- `belongs_to :post`, `belongs_to :category`
- Identity: unique on `[:post_id, :category_id]`

**`Content.PostTag`** (join table: `blog_post_tags`)
- `belongs_to :post`, `belongs_to :tag`
- Identity: unique on `[:post_id, :tag_id]`

**`Content.ChangelogEntry`** (table: `changelog_entries`)
- `id`, `version` (string, required), `title` (string, required), `body` (string, HTML), `type` (atom: feature/fix/improvement/breaking), `status` (atom: draft/published), `published_at`, timestamps
- Relationships: `belongs_to :author` (User)
- Actions: `:create`, `:update`, `:publish`, `:published` (read)

### Authorization

All Content resources use the same policy pattern:
- Published reads: open to everyone (public pages)
- All writes + draft reads: require `actor.is_admin == true`

This requires adding `is_admin :boolean, default: false` to `Accounts.User`.

### Routes

```
Public:
  /blog                          → Blog.BlogIndexLive
  /blog/category/:slug           → Blog.BlogCategoryLive
  /blog/tag/:slug                → Blog.BlogTagLive
  /blog/:slug                    → Blog.BlogPostLive
  /blog/feed.xml                 → FeedController :blog (XML)
  /changelog                     → ChangelogLive (refactored to DB)
  /changelog/feed.xml            → FeedController :changelog (XML)

Admin (inside admin live_session):
  /admin/blog                    → Admin.BlogListLive
  /admin/blog/new                → Admin.BlogEditorLive
  /admin/blog/:id/edit           → Admin.BlogEditorLive
  /admin/blog/categories         → Admin.BlogCategoriesLive
  /admin/blog/tags               → Admin.BlogTagsLive
  /admin/changelog               → Admin.ChangelogListLive
  /admin/changelog/new           → Admin.ChangelogEditorLive
  /admin/changelog/:id/edit      → Admin.ChangelogEditorLive
  /admin/seo                     → Admin.SeoDashboardLive
```

### Rich Text Editor: Tiptap

- Tiptap (headless ProseMirror-based) via npm in `assets/`
- LiveView hook `TiptapEditor` in `assets/js/hooks/tiptap_editor.js`
- Editor syncs HTML to a hidden textarea on content change
- Extensions: starter-kit, image, link, placeholder, code-block-lowlight
- Image upload: separate LiveView upload target, returns URL via `push_event` to Tiptap hook

### SEO Components

- **Dynamic meta tags**: Extend root layout to render `<meta>` tags from assigns (`page_title`, `page_description`, `og_image`, etc.)
- **JSON-LD**: New `FounderPad.Content.SeoHelpers` module with `article_json_ld/2`, `organization_json_ld/0`, `breadcrumb_json_ld/1`
- **Sitemap**: Extend existing `SitemapController` to query published blog posts + changelog entries
- **SEO Score**: Pure function module `Content.SeoScorer` checking title length, meta description, featured image, etc.
- **GSC Dashboard**: `Admin.SeoDashboardLive` reads from existing `SearchConsoleData` schema

### Oban Workers

- `Content.Workers.PublishScheduledPostsWorker` — Cron every 5 min, publishes posts where `scheduled_at <= now`
- `Content.Workers.ChangelogNotificationWorker` — Triggered on changelog publish, emails subscribers

### Shared Changes

- `Content.Changes.GenerateSlug` — Reusable Ash change for slugifying titles
- `Content.Changes.CalculateReadingTime` — Sets reading_time_minutes from body word count

---

## Sub-project 2: Admin Panel & API Key Management

### Admin Panel

No new Ash domain needed — the admin panel is a presentation layer reading from existing domains.

**User modifications:**
- Add `is_admin :boolean, default: false` to `Accounts.User`
- Add `suspended_at :utc_datetime_usec` to `Accounts.User`
- Add actions: `:suspend`, `:unsuspend`, `:list_all_users` (admin-only)

**New hook:** `FounderPadWeb.Hooks.RequireAdmin` — checks `current_user.is_admin`, redirects to `/dashboard` if false

**Impersonation:**
- Session stores `impersonating_user_id` + `admin_user_id`
- `AssignDefaults` hook loads impersonated user as `current_user`
- Banner in app layout: "You are impersonating [user]. [Stop]"
- All impersonation events audit-logged

**Admin LiveViews (at /admin/*):**
- `Admin.DashboardLive` — System overview (user count, org count, revenue, active subscriptions)
- `Admin.UsersLive` — User list with search, suspend/unsuspend, impersonate link
- `Admin.UserDetailLive` — Full user profile, memberships, activity
- `Admin.OrganisationsLive` — Org list, billing status
- `Admin.OrganisationDetailLive` — Org detail, subscription adjustments
- `Admin.SubscriptionsLive` — Subscription management
- `Admin.FeatureFlagsLive` — Toggle flags, set required_plan
- `Admin.AuditLogLive` — Full audit log viewer (reuses existing AuditLog resource)
- `Admin.EmailLogsLive` — Email delivery tracking

### New Domain: `FounderPad.ApiKeys`

**`ApiKeys.ApiKey`** (table: `api_keys`)
- `id`, `name` (string, human label), `key_prefix` (string, first 12 chars for display), `key_hash` (string, SHA-256, unique), `scopes` (array of atoms: read/write/admin), `last_used_at` (utc_datetime), `expires_at` (utc_datetime, optional), `revoked_at` (utc_datetime), `metadata` (map), timestamps
- Relationships: `belongs_to :organisation`, `belongs_to :created_by` (User)
- Actions: `:create` (generates key, stores hash, returns raw key once), `:revoke`, `:rotate` (create new + revoke old), `:touch_last_used`, `:active` (read: not revoked, not expired)

**Key generation:** `fp_live_` prefix + 32-byte random (base64). Store `key_hash = SHA-256(full_key)`. Raw key returned once on create, never stored.

**`ApiKeys.ApiKeyUsage`** (table: `api_key_usage`)
- `id`, `endpoint`, `method`, `status_code`, `response_time_ms`, `ip_address`, `inserted_at`
- Relationships: `belongs_to :api_key`

**New plug:** `FounderPadWeb.Plugs.ApiKeyAuth`
- Extracts Bearer token from Authorization header
- Hashes and looks up by `key_hash`
- Sets `conn.assigns.api_key` and `conn.assigns.current_organisation`
- Integrates with existing Hammer rate limiter (keyed by `api_key:<id>`)

**UI:** `ApiKeysLive` in the app settings area — create, view prefix, revoke, rotate, usage stats

---

## Sub-project 3: OAuth, GDPR & Email Templates

### OAuth / Social Login

**New resource:** `Accounts.SocialIdentity` (table: `social_identities`)
- `id`, `provider` (atom: google/github/microsoft), `provider_uid` (string), `provider_email` (string), `provider_data` (map), `linked_at` (utc_datetime), timestamps
- Relationships: `belongs_to :user`
- Identities: unique on `[:provider, :provider_uid]`, unique on `[:provider, :user_id]`

**AshAuthentication OAuth2 strategies** added to User resource for Google, GitHub, Microsoft. Config via env vars (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, etc.).

**Account linking logic** in `Accounts.OAuthHandler`:
1. If logged in + OAuth → link SocialIdentity to existing account
2. If not logged in → lookup by provider_uid → log in
3. If not logged in, no SocialIdentity, but email matches existing User → auto-link and log in
4. If completely new → create User + SocialIdentity

**Settings UI:** "Connected Accounts" section — show linked providers with Unlink, show unlinked with Connect. Require at least one auth method before unlinking.

### New Domain: `FounderPad.Privacy`

**`Privacy.CookieConsent`** (table: `cookie_consents`)
- `id`, `consent_id` (string, anonymous cookie ID), `analytics` (boolean), `marketing` (boolean), `functional` (boolean, always true), `ip_address`, `user_agent`, timestamps
- Relationships: `belongs_to :user` (optional)

**`Privacy.DataExportRequest`** (table: `data_export_requests`)
- `id`, `status` (atom: pending/processing/completed/failed/expired), `file_path`, `download_url` (signed, time-limited), `expires_at`, `completed_at`, `error`, timestamps
- Relationships: `belongs_to :user`

**`Privacy.DeletionRequest`** (table: `deletion_requests`)
- `id`, `status` (atom: pending/confirmed/soft_deleted/hard_deleted/cancelled), `confirmation_token`, `confirmed_at`, `soft_deleted_at`, `hard_delete_after` (30 days after confirmation), `hard_deleted_at`, timestamps
- Relationships: `belongs_to :user`

**Data export pipeline:**
1. User clicks "Export My Data" in Settings
2. `DataExportRequest` created (pending) + audit log
3. Oban `DataExportWorker` collects all user data across domains (profile, memberships, conversations, messages, billing, notifications, audit logs)
4. Bundled into JSON ZIP, stored temporarily
5. User emailed download link (valid 48h)

**Account deletion pipeline:**
1. User requests deletion → confirmation email with token
2. User confirms → immediate soft-delete (suspend user, anonymize email/name)
3. `hard_delete_after` set to 30 days out
4. Daily Oban cron `HardDeleteWorker` cascades hard delete past 30 days
5. During 30-day window, admin can cancel

**User modifications:** Add `email_preferences :map` to User — categories: marketing, product_updates, weekly_digest, billing, team

### Email Templates

**Shared module:** `Notifications.EmailLayout` — `wrap/3` function providing consistent branded HTML wrapper with logo, footer, unsubscribe link. All existing + new mailers refactored to use it.

**New mailers:**
- `OnboardingMailer` — welcome email + drip (day 1, 3, 7 via Oban scheduled jobs)
- `DigestMailer` — weekly usage summary (Oban cron: Monday 9am UTC)
- Extend `BillingMailer` — subscription_expiring, usage_threshold alerts
- `TeamMailer` — invite_accepted, member_removed

**Unsubscribe mechanism:**
- Signed Phoenix token encoding `{user_id, category}`
- `GET /unsubscribe/:token` → one-click unsubscribe (GDPR/CAN-SPAM compliant)
- Settings page: full email preferences panel with per-category toggles

**New Oban workers:**
- `OnboardingDripWorker` — scheduled at registration for day 1, 3, 7
- `WeeklyDigestWorker` — cron, queries active users with digest enabled
- `DataExportWorker` — generates ZIP for GDPR export
- `HardDeleteWorker` — daily cron, checks deletion_requests past 30 days
- `BillingAlertWorker` — checks expiring subscriptions

---

## Sub-project 4: Help Center & Error Pages

### New Domain: `FounderPad.HelpCenter`

**`HelpCenter.Category`** (table: `help_categories`)
- `id`, `name`, `slug` (unique), `description`, `icon` (string, Material Symbols name), `position` (integer), timestamps
- Relationships: `has_many :articles`

**`HelpCenter.Article`** (table: `help_articles`)
- `id`, `title`, `slug` (unique per category), `body` (Markdown), `excerpt`, `help_context_key` (string, e.g. "agents.create" for in-app linking), `status` (atom: draft/published/archived), `position` (integer), `published_at`, timestamps
- Generated column: `search_vector` (tsvector from title + excerpt + body, weighted A/B/C)
- GIN index on `search_vector`
- Relationships: `belongs_to :category`
- Actions: `:create`, `:update`, `:publish`, `:archive`, `:search` (full-text), `:by_context_key`, `:published`

**`HelpCenter.ContactRequest`** (table: `help_contact_requests`)
- `id`, `name`, `email`, `subject`, `message`, `status` (atom: new/in_progress/resolved), `user_id` (optional), timestamps

### Search: PostgreSQL Full-Text Search

```sql
ALTER TABLE help_articles ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(excerpt, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(body, '')), 'C')
  ) STORED;

CREATE INDEX help_articles_search_idx ON help_articles USING GIN (search_vector);
```

Custom Ash read action uses `plainto_tsquery` + `ts_rank` for ranked results.

### Routes

```
Public:
  /help                              → Help.HelpIndexLive
  /help/search                       → Help.HelpSearchLive
  /help/contact                      → Help.HelpContactLive
  /help/context/:context_key         → HelpContextController :redirect
  /help/:category_slug               → Help.HelpCategoryLive
  /help/:category_slug/:article_slug → Help.HelpArticleLive

Admin:
  /admin/help/categories             → Admin.Help.CategoryListLive
  /admin/help/articles               → Admin.Help.ArticleListLive
  /admin/help/articles/new           → Admin.Help.ArticleFormLive
  /admin/help/articles/:id/edit      → Admin.Help.ArticleFormLive
  /admin/help/contacts               → Admin.Help.ContactListLive
```

### In-App Contextual Help

New `help_link/1` function component in CoreComponents:
```heex
<.help_link context="agents.create" />
```
Renders a `?` icon linking to `/help/context/agents.create`, which redirects to the matching article.

### Error & Status Pages

**New templates** (standalone HTML, no JS dependencies):
- `error_html/429.html.heex` — Rate limit exceeded, retry countdown
- `error_html/402.html.heex` — Subscription required, CTA to /billing
- `error_html/503.html.heex` — Maintenance mode

**Enhanced existing:**
- `404.html.heex` — Add search box (to /help/search), navigation links
- `500.html.heex` — Add "we've been notified" + link to /help/contact

**Maintenance mode:**
- New plug `FounderPadWeb.Plugs.MaintenanceMode` in endpoint pipeline (before router, after static)
- Dual toggle: `maintenance_mode` feature flag (DB) OR `MAINTENANCE_MODE=true` env var
- Admin bypass via secret cookie (`maintenance_bypass`)
- Falls back to env var when DB is unavailable

---

## User Resource Changes (Consolidated)

All sub-projects modify `Accounts.User`. Consolidated list of new attributes:
- `is_admin :boolean, default: false` — Controls access to admin panel, blog CMS, help center admin, and all admin-only actions across all sub-projects
- `suspended_at :utc_datetime_usec` — When non-nil, login is blocked (Sub-project 2)
- `email_preferences :map, default: %{"marketing" => true, "product_updates" => true, "weekly_digest" => true, "billing" => true, "team" => true}` — Per-category email opt-out (Sub-project 3)

New relationships:
- `has_many :blog_posts, Content.Post, destination_attribute: :author_id` (Sub-project 1)
- `has_many :social_identities, Accounts.SocialIdentity` (Sub-project 3)

New authentication strategies:
- OAuth2: google, github, microsoft (Sub-project 3)

---

## Implementation Order

Each sub-project is a separate branch, spec, and implementation cycle:

1. **Sub-project 1: Content Engine** — Blog CMS + SEO + Changelog (~35 new files)
2. **Sub-project 2: Admin & API** — Admin Panel + API Keys (~25 new files)
3. **Sub-project 3: Auth, Privacy & Email** — OAuth + GDPR + Templates (~30 new files)
4. **Sub-project 4: Support & Polish** — Help Center + Error Pages (~20 new files)

Sub-project 2 depends on `is_admin` from Sub-project 1. Sub-project 3 is independent. Sub-project 4 depends on admin panel from Sub-project 2 for admin CRUD pages.

---

## Verification

For each sub-project:
1. Run `mix test` — all existing + new tests pass
2. Run `mix credo` — no new warnings
3. Run `mix dialyzer` — no new warnings
4. Manual verification: start server (`PORT=4004 mix phx.server`), navigate all new pages
5. Check SEO: view page source for meta tags, JSON-LD, canonical URLs
6. Check admin: create/edit/publish blog posts, manage changelog entries
7. Check public: browse /blog, /help, /changelog as unauthenticated user

---

## Critical Files Reference

### Existing files to modify
- `lib/founder_pad/accounts/resources/user.ex` — Add is_admin, suspended_at, email_preferences, social_identities, OAuth strategies
- `lib/founder_pad_web/router.ex` — Add all new routes (blog, admin, help, privacy, API keys)
- `lib/founder_pad_web/hooks/assign_defaults.ex` — Impersonation handling, suspended user blocking
- `lib/founder_pad_web/controllers/sitemap_controller.ex` — Include blog posts and changelog entries
- `lib/founder_pad_web/live/docs/changelog_live.ex` — Refactor from hardcoded to DB-backed
- `lib/founder_pad_web/components/core_components.ex` — Add help_link component
- `lib/founder_pad_web/controllers/error_html.ex` — Add 429, 402, 503 templates
- `lib/founder_pad_web/plugs/rate_limiter.ex` — API key auth integration
- `config/config.exs` — Register new Ash domains, Oban cron jobs, OAuth config
- `assets/js/app.js` — Register TiptapEditor hook
- `mix.exs` — Add Tiptap npm deps, earmark (optional)

### New directories
- `lib/founder_pad/content/` — Content domain (blog, changelog)
- `lib/founder_pad/api_keys/` — API key domain
- `lib/founder_pad/privacy/` — GDPR/privacy domain
- `lib/founder_pad/help_center/` — Help center domain
- `lib/founder_pad_web/live/blog/` — Public blog LiveViews
- `lib/founder_pad_web/live/help/` — Public help LiveViews
- `lib/founder_pad_web/live/admin/` — Admin LiveViews
- `assets/js/hooks/tiptap_editor.js` — Tiptap hook
