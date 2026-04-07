# FounderPad — Complete Feature List

## Core Platform (Pre-existing)

### Authentication & Identity
- Email/password registration and login
- Magic link authentication (passwordless)
- Password reset flow
- Session management with token-based auth
- AshAuthentication integration

### Multi-Tenant Workspaces
- Organisation creation and management
- User memberships with roles (owner, admin, member)
- Workspace switching
- Org-scoped data isolation
- Slug-based org URLs

### AI Agent Management
- Create, configure, and manage AI agents
- Multi-provider support (Anthropic Claude, OpenAI)
- Configurable system prompts, models, temperature, token limits
- Tool definitions per agent
- Real-time agent chat with streaming responses
- Conversation history and message archiving
- Tool call tracking (pending, running, completed, failed)

### Billing & Payments
- Stripe integration (checkout, subscriptions, webhooks)
- 4-tier plan management (Free, Starter, Pro, Enterprise)
- Per-plan limits: max seats, agents, API calls/month
- Monthly/yearly billing intervals
- Usage metering and tracking
- Invoice generation and history
- Subscription lifecycle (active, past_due, canceled, trialing)

### Team Management
- Member invitations with email delivery
- Role-based access control (owner/admin/member)
- Team activity tracking
- Member removal with notifications

### Notifications (In-App)
- Real-time in-app notifications via Phoenix PubSub
- Notification types: team_invite, team_removed, billing_warning, billing_updated, agent_completed, agent_failed, system_announcement
- Unread count tracking
- Mark as read (individual and bulk)

### Activity & Audit Logging
- Immutable audit logs (append-only, GDPR/SOC2 compliant)
- Event tracking: create, update, delete, login, logout, invite, role_change, subscription_change, API key events, settings changes
- ISO audit trail with IP addresses, user agents, metadata

### Analytics
- App event tracking with organisation scope
- Google Search Console data integration (keywords, impressions, clicks, CTR)
- Custom event recording

### Webhooks (Outbound)
- Custom webhook URL registration per organisation
- Event subscriptions
- Webhook secret rotation
- Delivery tracking with retry attempts
- Status monitoring (pending, delivered, failed)

### Feature Flags
- Global enable/disable toggles
- Per-plan feature gating
- Metadata storage for configuration
- Admin management UI

### Settings & Preferences
- User profile editing (name, avatar, preferences)
- Theme switching (dark/light mode)
- Password change
- Avatar upload with file storage

### Onboarding
- Multi-step wizard (org name, team invites, agent template, summary)
- Skip-if-done detection
- Dashboard banner for incomplete onboarding

### Documentation & Public Pages
- Landing page with marketing content
- Documentation hub (/docs)
- API specifications page (/docs/api)
- Dynamic changelog (/docs/changelog)

### API Layer
- REST API via JSON:API (auto-generated from Ash resources)
- GraphQL API via Absinthe (auto-generated from Ash resources)
- GraphiQL explorer (dev only)

---

## Sub-project 1: Content Engine (PR #8)

### Blog CMS
- **Use case:** Founders/admins publish blog posts to drive traffic and engage users
- Full admin dashboard CMS at `/admin/blog`
- Tiptap WYSIWYG rich text editor (headless ProseMirror) via LiveView JS hook
- Content workflow: Draft → Scheduled → Published → Archived
- Blog post attributes: title, slug (auto-generated), body (HTML), excerpt, featured image, reading time
- Category management with many-to-many relationships
- Tag management with many-to-many relationships
- Featured image upload
- Public blog pages: `/blog`, `/blog/:slug`, `/blog/category/:slug`, `/blog/tag/:slug`
- Paginated post listing with category filter pills
- Author byline with avatar and name
- Related posts suggestions on article pages
- Empty state for no-content scenarios

### SEO Engine
- **Use case:** Maximize search engine visibility for all public pages
- Dynamic meta tags per page (title, description)
- Open Graph tags (og:title, og:description, og:image, og:url, og:type)
- Twitter Card meta tags (summary_large_image)
- JSON-LD structured data (Article schema with author, publisher, dates)
- Canonical URL link tags
- Auto-generated sitemap.xml with all published blog posts
- Per-post SEO fields: meta_title, meta_description, og_image_url, canonical_url
- SEO Score calculator (8 checks: title length, meta description, excerpt, featured image, canonical URL, clean slug, body length, OG image)
- SEO Dashboard at `/admin/seo` with average scores, per-post analysis, failed checks

### Dynamic Changelog
- **Use case:** Keep users informed about product updates and releases
- Database-backed changelog (replaced hardcoded module attributes)
- Admin CRUD at `/admin/changelog`
- Entry attributes: version, title, body (HTML), type (feature/fix/improvement/breaking)
- Publish workflow with timestamps
- Type-colored badges (indigo=feature, green=fix, amber=improvement, red=breaking)
- Public changelog page at `/changelog`

### RSS Feeds
- **Use case:** Allow users to subscribe to content updates via RSS readers
- Blog RSS feed at `/blog/feed.xml`
- Changelog RSS feed at `/changelog/feed.xml`
- RSS 2.0 format with Atom self-link
- CDATA-wrapped content, RFC 822 date formatting

### Scheduled Publishing
- **Use case:** Queue posts for future publication
- Oban cron worker runs every 5 minutes
- Publishes posts where `scheduled_at <= now()`
- Automatic status transition from `:scheduled` to `:published`

### Reusable Ash Changes
- GenerateSlug — auto-generates URL-safe slugs from title or name attributes
- CalculateReadingTime — estimates reading time from HTML body word count (200 WPM)

---

## Sub-project 2: Admin & API Infrastructure (PR #9)

### Admin Panel
- **Use case:** Platform operators manage users, orgs, subscriptions, and system config
- Admin dashboard at `/admin` with system stats (users, orgs, API keys, feature flags)
- RequireAdmin hook gates all admin routes
- `is_admin` boolean on User resource

### User Management
- **Use case:** Admins monitor, support, and manage user accounts
- User list at `/admin/users` with search by email/name
- User detail view at `/admin/users/:id` with profile info and memberships
- Suspend/unsuspend users (`suspended_at` timestamp)
- Toggle admin status
- User impersonation (see below)

### Organisation Management
- **Use case:** Admins view and manage all organisations
- Organisation list at `/admin/organisations` with member counts
- Organisation detail with membership and billing info

### Subscription Management
- **Use case:** Admins monitor subscription health across the platform
- Subscription list at `/admin/subscriptions`
- View plan, status, period dates, cancellation status per org

### Feature Flag Management
- **Use case:** Admins control feature rollouts without code deploys
- Feature flags list at `/admin/feature-flags`
- Toggle switches for enable/disable
- Required plan display
- Real-time toggle via Ash `:toggle` action

### API Key Management
- **Use case:** Users generate API keys for programmatic access; admins monitor usage
- New `ApiKeys` Ash domain with ApiKey and ApiKeyUsage resources
- SHA-256 hashed key storage (raw key shown once on creation, never stored)
- Key prefix pattern: `fp_` + 8 chars for display
- Scoped permissions: read, write, admin
- Key lifecycle: create, revoke, rotate
- `last_used_at` tracking (async update on API call)
- Expiration support
- User-facing management at `/api-keys` — create, view, revoke keys
- Create form with name and scope checkboxes
- Raw key displayed once in dismissible banner after creation

### API Key Authentication
- **Use case:** Authenticate API requests with Bearer tokens
- `ApiKeyAuth` plug in the API pipeline
- Extracts Bearer token from Authorization header
- Hashes token with SHA-256, looks up by hash
- Sets `conn.assigns.api_key` and `conn.assigns.current_organisation`
- Gracefully passes through when no key provided (for public endpoints)
- Revoked keys are rejected

### User Impersonation
- **Use case:** Admins debug issues by viewing the app as a specific user
- Session-based impersonation (no token exchange)
- Start via `/admin/impersonate/:id` (controller sets session key)
- Stop via `/admin/stop-impersonation` (clears session key)
- AssignDefaults hook swaps `current_user` to impersonated user
- `admin_user` preserved in assigns for identity
- Amber banner at top of app: "Impersonating: [user] | End Impersonation"

---

## Sub-project 3: Auth, Privacy & Email (PR #11)

### OAuth Social Login
- **Use case:** Users sign in with existing Google, GitHub, or Microsoft accounts
- `SocialIdentity` Ash resource tracks linked OAuth providers per user
- Attributes: provider (google/github/microsoft), provider_uid, provider_email, provider_data
- Unique constraints: provider+uid, provider+user
- OAuth callback controller (placeholder — requires provider credentials)
- Runtime config for client IDs and secrets (env vars)
- Ready for Google, GitHub, Microsoft integration

### GDPR Compliance — Cookie Consent
- **Use case:** Comply with EU cookie laws by tracking user consent
- `CookieConsent` Ash resource in Privacy domain
- Tracks: consent_id, analytics (boolean), marketing (boolean), functional (always true)
- Records IP address and user agent for audit
- API endpoint at `POST /api/privacy/cookie-consent`
- Sets response cookie for consent tracking

### GDPR Compliance — Data Export
- **Use case:** Users exercise right to data portability (GDPR Article 20)
- `DataExportRequest` Ash resource with status workflow (pending → processing → completed → expired)
- `DataExportWorker` Oban job collects user data into JSON file
- Exports: profile, preferences, email preferences
- 48-hour download link expiration
- Error handling with failure status tracking

### GDPR Compliance — Account Deletion
- **Use case:** Users exercise right to erasure (GDPR Article 17)
- `DeletionRequest` Ash resource with full lifecycle (pending → confirmed → soft_deleted → hard_deleted)
- Confirmation token generated on request
- 30-day grace period after confirmation
- `HardDeleteWorker` Oban cron job runs daily at 3am UTC
- Cancellation possible during grace period
- Soft delete: suspend user, anonymize data
- Hard delete: cascade remove all user data

### Email Preferences
- **Use case:** Users control which emails they receive (CAN-SPAM/GDPR compliance)
- `email_preferences` map on User resource
- Categories: marketing, product_updates, weekly_digest, billing, team
- All default to true (opt-out model)
- `update_email_preferences` action on User

### One-Click Unsubscribe
- **Use case:** Users instantly opt out of email categories via link in emails
- Signed Phoenix token encoding `{user_id, category}`
- `GET /unsubscribe/:token` — one-click unsubscribe (GDPR/CAN-SPAM compliant)
- 30-day token validity
- Success/error HTML pages
- Updates user's email_preferences automatically

### Shared Email Layout
- **Use case:** All transactional emails use consistent branding
- `EmailLayout.wrap/3` function wraps content in branded HTML
- FounderPad header with primary color (#4648d4)
- Footer with copyright and optional unsubscribe link
- Preheader text support
- `unsubscribe_url/2` helper generates signed unsubscribe links

### Onboarding Drip Emails
- **Use case:** Guide new users through product setup with timed emails
- `OnboardingMailer` with 3 emails: welcome, day-1 tips, day-3 check-in
- `OnboardingDripWorker` Oban worker sends drip on day 1 and 3
- Respects email preferences (checks `product_updates` opt-out)
- Each email includes unsubscribe link

### Weekly Digest
- **Use case:** Keep users engaged with a weekly activity summary
- `WeeklyDigestWorker` Oban cron job runs Mondays at 9am UTC
- Queries users with `weekly_digest` preference enabled
- Sends branded digest email with dashboard link
- Includes unsubscribe link

### Privacy & Terms Pages
- **Use case:** Legal compliance — inform users about data practices
- Static `/privacy` page with GDPR rights section (access, deletion, portability, opt-out)
- Static `/terms` page with terms of service
- Cookie policy section
- Contact support link
- Privacy link in app sidebar and footer

---

## Sub-project 4: Help Center & Error Pages (PR #10)

### Help Center
- **Use case:** Users find answers to common questions without contacting support
- New `HelpCenter` Ash domain with Category, Article, ContactRequest resources
- Categories with: name, slug, description, icon (Material Symbols), position ordering
- Articles with: title, slug, body (HTML), excerpt, help_context_key, status workflow, position ordering
- Public pages: `/help` (category grid + search), `/help/:category/:slug` (article), `/help/search` (results)

### Full-Text Search
- **Use case:** Users search help articles by keyword with ranked results
- PostgreSQL `tsvector` with GIN index (no external search service needed)
- Weighted search: title (highest) → excerpt → body (lowest)
- `plainto_tsquery` for natural language queries
- Stemming support ("billing" matches "billed")
- Ranked by relevance via `ts_rank`

### Contact Support Form
- **Use case:** Users reach support when help articles aren't enough
- Contact form at `/help/contact`
- Fields: name, email, subject, message
- Creates `ContactRequest` Ash resource (status: new → in_progress → resolved)

### In-App Contextual Help
- **Use case:** Users access relevant help from anywhere in the app
- `<.help_link context="agents.create" />` component in CoreComponents
- Renders a `?` icon linking to `/help/search?q={context}`
- Can be placed next to any feature for contextual guidance

### Admin Help Management
- **Use case:** Admins create and manage help articles
- Article list at `/admin/help` with status filter and CRUD
- Article editor at `/admin/help/new` and `/admin/help/:id/edit`
- Category selector, status workflow, help_context_key field
- Publish/archive actions

### Error Pages
- **Use case:** Provide branded, helpful error experiences instead of generic defaults
- **404 Not Found** — "Lost in the void." with search help link and back button
- **500 Internal Error** — "Something broke." with contact support link
- **429 Rate Limit** — "Too many requests." with retry message
- **402 Subscription Required** — "Upgrade required." with billing CTA
- **503 Maintenance** — "We'll be right back." with no CTA
- All pages: self-contained HTML, inline CSS, no JS dependencies, dark theme, Material Symbols icons

### Maintenance Mode
- **Use case:** Gracefully take the app offline during planned maintenance
- `MaintenanceMode` plug in endpoint pipeline (before router, after session)
- Dual toggle: `maintenance_mode` feature flag (DB) OR `MAINTENANCE_MODE=true` env var
- Env var fallback works when database is unavailable
- Admin bypass via `maintenance_bypass` cookie
- Serves branded 503 page with inline HTML

---

## Sub-project 5: Push Notifications (PR #12)

### Push Notification System
- **Use case:** Users receive real-time alerts on their phone/browser when events occur
- 4th notification channel alongside in-app, email, and background jobs
- `PushSubscription` Ash resource stores device tokens per user
- Supports both FCM (mobile) and Web Push (browser) subscription types
- Multiple devices per user
- Active/deactivate lifecycle with `last_used_at` tracking

### FCM (Firebase Cloud Messaging) Integration
- **Use case:** Send push notifications to native mobile apps (iOS/Android)
- FCM HTTP v1 API via `Req` HTTP client
- Payload builder with notification title, body, and action URL data
- Google OAuth2 JWT flow for server-to-server auth
- Configurable via `FIREBASE_SERVICE_ACCOUNT_JSON` env var
- Graceful no-op when credentials not configured

### Web Push (Browser Notifications)
- **Use case:** Send push notifications to desktop/mobile browsers without a native app
- Service worker at `/service-worker.js` handles push display and notification clicks
- LiveView hook requests browser permission and registers subscription
- VAPID key authentication (standard Web Push protocol)
- Notification click opens relevant URL or focuses existing window
- Configurable via `VAPID_PUBLIC_KEY` and `VAPID_PRIVATE_KEY` env vars

### Push Notification Worker
- **Use case:** Reliably deliver push notifications to all user devices
- `PushNotificationWorker` Oban job dispatched on every `broadcast_to_user/2` call
- Loads all active push subscriptions for target user
- Sends to each device via appropriate channel (FCM or Web Push)
- Touches `last_used_at` on successful delivery
- Max 3 retry attempts on failure

### Push Subscription Management
- **Use case:** Register and manage device push subscriptions
- API endpoint at `POST /api/push/subscribe` for device registration
- Duplicate subscription handling (idempotent creates)
- Deactivation support for stale subscriptions
- "Enable Notifications" button in app header toolbar

### Automatic Push Integration
- **Use case:** Every notification automatically triggers push — no per-feature wiring needed
- `broadcast_to_user/2` extended to enqueue push worker alongside PubSub broadcast
- All existing notification types automatically send push: team_invite, team_removed, billing_warning, billing_updated, agent_completed, agent_failed, system_announcement
- No changes needed to notification callers — push is transparent

---

## Technical Summary

| Metric | Count |
|--------|-------|
| Total Ash Domains | 12 (Accounts, Billing, AI, Notifications, Audit, FeatureFlags, Webhooks, Analytics, Content, ApiKeys, Privacy, HelpCenter) |
| Total Ash Resources | ~35 |
| Total LiveViews | ~40 |
| Total Tests | 389 |
| Pull Requests | 5 (#8, #9, #10, #11, #12) |
| New Files Created | ~120 |

### Environment Variables Required

| Variable | Purpose | Required |
|----------|---------|----------|
| `DATABASE_URL` | PostgreSQL connection | Yes |
| `SECRET_KEY_BASE` | Phoenix session encryption | Yes |
| `RESEND_API_KEY` | Email delivery via Resend | Yes (prod) |
| `STRIPE_SECRET_KEY` | Stripe payments | Yes (prod) |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook verification | Yes (prod) |
| `ANTHROPIC_API_KEY` | Claude AI provider | Yes (for AI) |
| `OPENAI_API_KEY` | OpenAI provider | Optional |
| `GOOGLE_CLIENT_ID` | Google OAuth | Optional |
| `GOOGLE_CLIENT_SECRET` | Google OAuth | Optional |
| `GITHUB_CLIENT_ID` | GitHub OAuth | Optional |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth | Optional |
| `MICROSOFT_CLIENT_ID` | Microsoft OAuth | Optional |
| `MICROSOFT_CLIENT_SECRET` | Microsoft OAuth | Optional |
| `VAPID_PUBLIC_KEY` | Web Push notifications | Optional |
| `VAPID_PRIVATE_KEY` | Web Push notifications | Optional |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | FCM push notifications | Optional |
| `PLAUSIBLE_DOMAIN` | Analytics | Optional |
| `MAINTENANCE_MODE` | Maintenance toggle | Optional |
