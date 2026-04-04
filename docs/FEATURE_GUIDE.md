# FounderPad — Complete Feature Guide

Every feature explained: what it does, how it works technically, and why it matters for your SaaS.

---

## 1. Authentication & Identity

### 1.1 Email/Password Registration & Login

**What:** Users create accounts with email and password, then log in to access the app.

**How:** Uses AshAuthentication 4.x with a `:password` strategy on the User resource. Passwords are hashed with bcrypt (`bcrypt_elixir`). Registration at `/auth/register` creates the User via the `:register_with_password` action. Login at `/auth/login` verifies credentials and sets a session token. The `AuthSessionController` manages session cookies — LiveView can't set cookies directly, so the controller bridges that gap.

**Why:** Email/password is the baseline auth every SaaS needs. It's the simplest onboarding path with zero third-party dependencies.

**Files:** `lib/founder_pad/accounts/resources/user.ex`, `lib/founder_pad_web/live/auth/login_live.ex`, `lib/founder_pad_web/live/auth/register_live.ex`, `lib/founder_pad_web/controllers/auth_session_controller.ex`

---

### 1.2 Magic Link Authentication

**What:** Users can request a one-time login link sent to their email — no password needed.

**How:** AshAuthentication's `:magic_link` strategy generates a signed token, sends it via `MagicLinkSender` (which uses Swoosh/Resend), and verifies it on click. The token is single-use and time-limited.

**Why:** Reduces friction for users who forget passwords. Common in modern SaaS (Slack, Notion). Also useful for inviting team members who don't have accounts yet.

**Files:** `lib/founder_pad/accounts/resources/user.ex` (strategies block), `lib/founder_pad/accounts/senders/magic_link_sender.ex`

---

### 1.3 Two-Factor Authentication (2FA/TOTP)

**What:** Users add an extra security layer by linking an authenticator app (Google Authenticator, Authy). After entering their password, they must also enter a 6-digit time-based code.

**How:** The `UserTotp` Ash resource stores a base32-encoded secret per user. On setup, the secret is generated with `:crypto.strong_rand_bytes(20)` and displayed for the user to scan into their authenticator app. Verification uses the TOTP algorithm (RFC 6238): the secret and current Unix time are combined with HMAC-SHA1 to produce a 6-digit code that changes every 30 seconds. A 1-window tolerance (previous + next code) handles clock drift. Eight backup codes are generated for account recovery.

**Why:** Required for enterprise customers and any SaaS handling sensitive data. Prevents account takeover even if passwords are compromised.

**Files:** `lib/founder_pad/accounts/resources/user_totp.ex`, `lib/founder_pad_web/live/two_factor_live.ex`

---

### 1.4 OAuth Social Login (Google, GitHub, Microsoft)

**What:** Users sign in with their existing Google, GitHub, or Microsoft accounts instead of creating a new password.

**How:** The `SocialIdentity` Ash resource tracks linked OAuth providers per user (provider, provider_uid, provider_email, provider_data). An `OAuthCallbackController` handles the redirect flow. The system is scaffolded — actual OAuth requires setting provider client IDs and secrets as environment variables. AshAuthentication has built-in Assent integration for the token exchange.

**Why:** Reduces signup friction by 30-50%. Google covers business users, GitHub covers developers, Microsoft covers enterprise. Users don't need to create yet another password.

**Files:** `lib/founder_pad/accounts/resources/social_identity.ex`, `lib/founder_pad_web/controllers/oauth_callback_controller.ex`, `config/runtime.exs` (OAuth config)

---

## 2. Multi-Tenant Workspaces

### 2.1 Organisation Management

**What:** Users create organisations (workspaces) that contain their agents, billing, team members, and data. Each organisation is isolated — users can belong to multiple orgs.

**How:** The `Organisation` Ash resource has a name and auto-generated slug. The `Membership` resource is the join table between User and Organisation, with a role field (`:owner`, `:admin`, `:member`). Data isolation happens at the query level — each resource that's org-scoped has an `organisation_id` foreign key, and queries filter by the current user's active org.

**Why:** Multi-tenancy is the foundation of any B2B SaaS. Teams need isolated workspaces where their data isn't visible to other customers.

**Files:** `lib/founder_pad/accounts/resources/organisation.ex`, `lib/founder_pad/accounts/resources/membership.ex`

---

### 2.2 Role-Based Access Control (RBAC)

**What:** Three roles control what users can do within an organisation: Owner (full control), Admin (manage team + settings), Member (use features).

**How:** The `role` atom on `Membership` determines permissions. Ash policies check the actor's role via `expr(^actor(:role))` or custom checks. The UI conditionally renders buttons/sections based on the user's role in their current org.

**Why:** Not everyone on a team should have the same permissions. Owners need billing access, admins need team management, but regular members just need to use the product.

**Files:** `lib/founder_pad/accounts/resources/membership.ex` (role field + policies)

---

## 3. AI Agent Management

### 3.1 Agent CRUD

**What:** Users create, configure, and manage AI agents. Each agent has a name, description, system prompt, model selection, provider, temperature, and token limits.

**How:** The `Agent` Ash resource stores configuration. The `AgentsLive` page shows a grid/list of agents. `AgentCreateLive` handles the creation form. All agents are scoped to an organisation.

**Why:** This is FounderPad's core value proposition — orchestrating AI agents. The configuration interface lets non-technical users set up agents without writing code.

**Files:** `lib/founder_pad/ai/resources/agent.ex`, `lib/founder_pad_web/live/agents_live.ex`, `lib/founder_pad_web/live/agent_create_live.ex`

---

### 3.2 Real-Time Agent Chat

**What:** Users have conversations with their AI agents in a real-time chat interface. Messages stream in as the agent generates them.

**How:** The `Conversation` and `Message` Ash resources store chat history. `AgentDetailLive` manages the chat UI. When a user sends a message, an Oban job (`AgentRunner`) calls the AI provider API (Anthropic or OpenAI via `Req` HTTP client). Responses stream back via Phoenix PubSub to the LiveView, which updates the UI in real-time. Tool calls are tracked in the `ToolCall` resource with status (pending → running → completed/failed).

**Why:** Chat is the primary interface for AI agents. Real-time streaming gives immediate feedback and makes the experience feel responsive.

**Files:** `lib/founder_pad/ai/resources/conversation.ex`, `lib/founder_pad/ai/resources/message.ex`, `lib/founder_pad/ai/resources/tool_call.ex`, `lib/founder_pad_web/live/agent_detail_live.ex`

---

### 3.3 Agent Templates / Marketplace

**What:** Pre-built agent templates (Customer Support Bot, Code Review Assistant, Content Writer, Data Analyst, Meeting Summarizer) that users can clone to get started quickly.

**How:** The `AgentTemplate` Ash resource stores template configurations (name, description, category, system_prompt, model, provider, icon, featured flag, use_count). The marketplace at `/agents/templates` shows templates in a grid with category filter tabs. "Use Template" clones the template into a new agent in the user's org and increments the `use_count`. Admin CRUD at `/admin/templates` manages templates.

**Why:** Reduces time-to-value from hours to seconds. New users don't need to figure out system prompts from scratch — they pick a template and customize it. The marketplace also showcases what's possible with the platform.

**Files:** `lib/founder_pad/ai/resources/agent_template.ex`, `lib/founder_pad_web/live/agent_templates_live.ex`, `lib/founder_pad_web/live/admin/agent_templates_live.ex`

---

### 3.4 Agent Analytics Dashboard

**What:** Per-agent usage metrics showing conversations, messages, token usage, costs, response times, and tool call success/failure rates.

**How:** `AgentAnalyticsLive` at `/agents/:id/analytics` queries existing `Conversation`, `Message`, and `ToolCall` resources. It aggregates: total conversations, total messages, sum of `token_count` and `cost_cents` from Messages, average `duration_ms` from ToolCalls, and pass/fail counts from ToolCall statuses. All data comes from existing tables — no new resources needed.

**Why:** Users need visibility into how their agents perform and how much they cost. This data drives optimization decisions (adjust temperature, improve prompts, switch models).

**Files:** `lib/founder_pad_web/live/agent_analytics_live.ex`

---

## 4. Billing & Payments

### 4.1 Stripe Integration

**What:** Full payment processing with Stripe — checkout, subscriptions, webhooks, invoices.

**How:** Uses `stripity_stripe` library. Plans are stored in the `Plan` resource with Stripe product/price IDs. `CheckoutController` creates Stripe Checkout sessions. `WebhookController` processes Stripe events (subscription created/updated/deleted, payment succeeded/failed). The `Subscription` resource tracks status (active, past_due, canceled, trialing) and syncs with Stripe via webhooks.

**Why:** You can't have a SaaS without payments. Stripe is the industry standard — handles PCI compliance, international payments, and subscription management.

**Files:** `lib/founder_pad/billing/resources/plan.ex`, `lib/founder_pad/billing/resources/subscription.ex`, `lib/founder_pad/billing/resources/invoice.ex`, `lib/founder_pad_web/controllers/checkout_controller.ex`, `lib/founder_pad_web/controllers/webhook_controller.ex`

---

### 4.2 Four-Tier Plan System

**What:** Free, Starter ($29/mo), Pro ($79/mo), Enterprise ($199/mo) with escalating limits on workspaces, agents, API calls, and team seats.

**How:** Plan configuration in `config/plans.exs` defines limits per tier. The `Plan` resource stores these in the database with Stripe IDs. The `BillingLive` page shows current plan, usage, available upgrades, and invoice history. Plan limits are enforced at the application layer when creating agents, inviting members, or making API calls.

**Why:** Tiered pricing is the most common SaaS model. It lets you serve free users (lead generation), small teams (Starter), growing companies (Pro), and enterprises (custom). Each tier's limits create natural upgrade pressure.

**Files:** `config/plans.exs`, `lib/founder_pad/billing/resources/plan.ex`, `lib/founder_pad_web/live/billing_live.ex`

---

### 4.3 Usage-Based Billing Tracker

**What:** Tracks API calls per organisation against plan limits. Shows a usage dashboard with current period consumption.

**How:** `UsageTracker` module provides `track_api_call/1` (records a usage event), `get_usage_count/2` (counts events in current period), and `within_limits?/1` (checks against plan's `max_api_calls_per_month`). The `UsageLive` page at `/usage` shows a CSS bar chart of API calls used vs. limit, current plan info, and usage history. Data is stored in the existing `UsageRecord` resource.

**Why:** Usage-based pricing aligns cost with value — customers who use more, pay more. The dashboard gives visibility so users aren't surprised by overages. It also creates natural upgrade triggers when users approach their limits.

**Files:** `lib/founder_pad/billing/usage_tracker.ex`, `lib/founder_pad_web/live/usage_live.ex`

---

## 5. Team Management

### 5.1 Member Invitations

**What:** Org owners/admins invite new members by email. Invitees receive an email with a link to join.

**How:** `TeamLive` handles the invitation flow. An invitation email is sent via Swoosh/Resend. When the invitee clicks the link, they're prompted to register (if new) or added to the org (if existing). The `Membership` resource is created with the specified role.

**Why:** Teams need to onboard new members without manual account creation. Email invitations are the standard pattern.

**Files:** `lib/founder_pad_web/live/team_live.ex`, `lib/founder_pad/notifications/mailers/`

---

## 6. Notifications

### 6.1 In-App Real-Time Notifications

**What:** Users receive instant notifications inside the app — team invites, agent completions, billing warnings, system announcements. A bell icon shows unread count.

**How:** The `Notification` Ash resource stores notifications with type, title, body, action_url, and read status. When a notification is created, `broadcast_to_user/2` publishes it via Phoenix PubSub on `"user_notifications:{user_id}"`. The `NotificationHandler` on_mount hook subscribes to this channel, so LiveViews receive updates instantly without polling. The notification dropdown in the app header shows the 10 most recent unread notifications.

**Why:** Real-time notifications keep users engaged and informed without leaving the app. PubSub is zero-latency — no polling, no external service.

**Files:** `lib/founder_pad/notifications/resources/notification.ex`, `lib/founder_pad/notifications/notifications.ex`, `lib/founder_pad_web/hooks/notification_handler.ex`

---

### 6.2 Email Notifications

**What:** Transactional emails for auth (welcome, magic link, password reset), billing (subscription, payment), agent events (completion, failure), and team activity.

**How:** Four mailer modules use Swoosh to compose emails: `AuthMailer`, `BillingMailer`, `AgentMailer`, `OnboardingMailer`. Each email is wrapped in the shared `EmailLayout` branded template. Emails are delivered via Resend (production) or local adapter (development). The `EmailLog` resource tracks delivery status (pending, sent, failed, bounced) for auditing.

**Why:** Email is the fallback notification channel — it reaches users even when they're not in the app. Transactional emails (welcome, password reset) are essential for any SaaS.

**Files:** `lib/founder_pad/notifications/mailers/`, `lib/founder_pad/notifications/email_layout.ex`, `lib/founder_pad/notifications/resources/email_log.ex`

---

### 6.3 Push Notifications (FCM + Web Push)

**What:** Phone and browser push notifications for all event types. Users click "Enable Notifications" in the app header to subscribe.

**How:** The `PushSubscription` resource stores device tokens per user (type: `:fcm` or `:web_push`). When `broadcast_to_user/2` is called, it now also enqueues a `PushNotificationWorker` Oban job. The worker loads all active subscriptions for that user and dispatches:
- **FCM:** HTTP POST to Google's FCM v1 API with a JSON payload (notification title, body, action URL). Requires a Firebase service account JSON for server-to-server auth.
- **Web Push:** Uses the Web Push protocol with VAPID keys. A service worker (`priv/static/service-worker.js`) receives the push event and displays a browser notification. Clicking the notification opens the relevant URL.

The JavaScript hook (`PushNotifications`) handles the browser flow: requests notification permission, registers the service worker, subscribes via the Push API with the VAPID public key, and sends the subscription to the server via `POST /api/push/subscribe`.

**Why:** Push notifications re-engage users who aren't actively using the app. They're especially important for time-sensitive events (agent completed, payment failed, team invite). Web Push works on desktop and mobile browsers without a native app. FCM covers native iOS/Android apps.

**Files:** `lib/founder_pad/notifications/resources/push_subscription.ex`, `lib/founder_pad/notifications/push_sender.ex`, `lib/founder_pad/notifications/workers/push_notification_worker.ex`, `priv/static/service-worker.js`, `assets/js/hooks/push_notifications.js`, `lib/founder_pad_web/controllers/push_subscription_controller.ex`

---

### 6.4 Onboarding Drip Emails

**What:** Automated email sequence after registration: welcome email, day-1 tips, day-3 check-in.

**How:** `OnboardingMailer` has three email functions: `welcome/1`, `day_one_tips/1`, `day_three_check_in/1`. The `OnboardingDripWorker` Oban worker is scheduled with delays (1 day, 3 days). Before sending, it checks the user's `email_preferences["product_updates"]` — if opted out, the email is skipped. Each email uses the branded `EmailLayout` wrapper with an unsubscribe link.

**Why:** Onboarding drip emails increase activation rates by 30-50%. Users who don't engage in the first week rarely come back. Timed tips guide them through key features without overwhelming them on day one.

**Files:** `lib/founder_pad/notifications/mailers/onboarding_mailer.ex`, `lib/founder_pad/notifications/workers/onboarding_drip_worker.ex`

---

### 6.5 Weekly Digest

**What:** Monday morning email summarizing the past week's activity.

**How:** `WeeklyDigestWorker` Oban cron job runs every Monday at 9am UTC. It queries all users with `email_preferences["weekly_digest"] != false`, then sends a branded digest email with a dashboard link. The digest respects unsubscribe preferences.

**Why:** Weekly digests keep users engaged even during inactive periods. They remind users the product exists and highlight activity they might have missed.

**Files:** `lib/founder_pad/notifications/workers/weekly_digest_worker.ex`

---

## 7. Audit & Activity Logging

### 7.1 Immutable Audit Log

**What:** Every significant action is logged: create, update, delete, login, logout, invite, role change, subscription change, API key events, settings changes. Logs are append-only and cannot be modified or deleted.

**How:** The `AuditLog` Ash resource stores: action (atom), resource_type, resource_id, actor_id, organisation_id, changes (map of before/after), metadata (map), ip_address, and user_agent. The resource has no `:update` or `:destroy` actions — only `:create` — making it immutable. Timestamps are set once on creation and never modified.

**Why:** Audit logs are required for SOC 2 compliance, GDPR accountability, and security incident investigation. Immutability ensures the log can't be tampered with after the fact.

**Files:** `lib/founder_pad/audit/resources/audit_log.ex`

---

### 7.2 Enhanced Audit Log Viewer

**What:** A searchable, filterable UI for browsing audit logs at `/audit-log`.

**How:** `AuditLogLive` displays logs in a table with: action type filter buttons, resource type quick filters, text search across actors and resources, expandable rows showing `changes` and `metadata` as formatted JSON, and actor details (email, IP, user agent). Supports CSV export.

**Why:** Audit logs are useless if you can't search them. Admins need to quickly answer "who changed what, when?" during incident investigations or compliance audits.

**Files:** `lib/founder_pad_web/live/audit_log_live.ex`

---

## 8. Analytics

### 8.1 App Event Tracking

**What:** Custom event recording for product analytics — tracks user actions with metadata.

**How:** The `AppEvent` Ash resource stores: event_name, actor_id, organisation_id, metadata (map), occurred_at. Events are created via `Ash.create!()` from anywhere in the app.

**Why:** First-party analytics give you data ownership and custom event tracking without depending on external tools. You can answer product questions like "how many users created an agent this week?"

**Files:** `lib/founder_pad/analytics/resources/app_event.ex`

---

### 8.2 Google Search Console Integration

**What:** Stores keyword/page performance data from Google Search Console — impressions, clicks, position, CTR.

**How:** The `SearchConsoleData` resource stores fetched GSC data. The SEO dashboard at `/admin/seo` displays this data alongside per-post SEO scores. Requires `GSC_CREDENTIALS_JSON` env var for API access.

**Why:** SEO is a primary growth channel for SaaS. GSC data shows which keywords drive traffic, which pages rank, and where there are opportunities to improve.

**Files:** `lib/founder_pad/analytics/resources/search_console_data.ex`, `lib/founder_pad_web/live/admin/seo_dashboard_live.ex`

---

## 9. Webhooks

### 9.1 Outbound Webhooks

**What:** Users register webhook URLs to receive event notifications (HTTP POST with JSON payload) when things happen in their org.

**How:** The `OutboundWebhook` resource stores: url, secret (for payload signing), events array (which events to deliver), active flag, organisation_id. The `WebhookDelivery` resource tracks each delivery attempt: event_type, payload (map), response_status, response_body, error, attempts count, status (pending/delivered/failed). Failed deliveries are retried with exponential backoff.

**Why:** Webhooks let users integrate FounderPad with their own systems (Slack, Zapier, custom backends) without polling the API. It's the standard integration pattern for modern SaaS.

**Files:** `lib/founder_pad/webhooks/resources/outbound_webhook.ex`, `lib/founder_pad/webhooks/resources/webhook_delivery.ex`

---

### 9.2 Webhook Logs Viewer

**What:** UI at `/webhooks` showing webhook configurations and delivery history with payload inspection.

**How:** `WebhookLogsLive` lists all outbound webhooks for the user's org. Each webhook row expands to show delivery history: event type, status badge (pending/delivered/failed), HTTP response status, attempt count, and the full JSON payload. Failed deliveries have a "Retry" button that re-enqueues the delivery job.

**Why:** When webhook integrations break, users need to see what went wrong — was it a network error? A 500 from their server? Was the payload malformed? Self-service debugging reduces support tickets.

**Files:** `lib/founder_pad_web/live/webhook_logs_live.ex`

---

## 10. Feature Flags

### 10.1 Feature Flag System

**What:** Toggle features on/off globally or per plan tier without deploying code.

**How:** The `FeatureFlag` resource stores: key (unique string), name, description, enabled (boolean), required_plan (optional string), metadata. The `FeatureFlags.enabled?/2` function evaluates a flag with context: checks the enabled boolean, then compares the required_plan against the user's current plan using a hierarchy (`free < starter < pro < enterprise`). The admin UI at `/admin/feature-flags` shows all flags with toggle switches.

**Why:** Feature flags decouple deployment from release. You can deploy code with a flag off, turn it on for beta testers, then gradually roll out to everyone. They're also useful for emergency kill switches and plan-based feature gating.

**Files:** `lib/founder_pad/feature_flags/resources/feature_flag.ex`, `lib/founder_pad/feature_flags/feature_flags.ex`, `lib/founder_pad_web/live/admin/feature_flags_live.ex`

---

## 11. Content Management

### 11.1 Blog CMS

**What:** Full-featured blog with a WYSIWYG editor, categories, tags, drafts, scheduling, and SEO fields.

**How:** The `Content` Ash domain has 6 resources: Post, Category, Tag, PostCategory (join), PostTag (join), ChangelogEntry. The admin CMS at `/admin/blog` provides full CRUD. The editor uses Tiptap (headless ProseMirror) via a LiveView JavaScript hook — the editor syncs HTML content to a hidden textarea on every keystroke, so the LiveView form receives it as a regular field. Featured image upload uses Phoenix LiveView's `allow_upload/3`. Posts have SEO fields (meta_title, meta_description, og_image_url, canonical_url) and a reading time calculator.

Public pages at `/blog` display published posts in a responsive grid with category filter pills. Individual posts at `/blog/:slug` show the full article with author byline, categories, tags, and related posts.

**Why:** A blog is the #1 content marketing tool for SaaS. It drives organic traffic (SEO), establishes authority, and provides a place to announce features. Having it built-in means buyers don't need to bolt on WordPress or another CMS.

**Files:** `lib/founder_pad/content/` (domain + resources), `lib/founder_pad_web/live/blog/` (public pages), `lib/founder_pad_web/live/admin/blog_*.ex` (admin CMS), `assets/js/hooks/tiptap_editor.js`

---

### 11.2 Dynamic Changelog

**What:** Product changelog showing releases with version numbers, types (feature/fix/improvement/breaking), and release notes.

**How:** The `ChangelogEntry` resource stores: version, title, body (HTML), type (atom), status, published_at. The public page at `/changelog` queries published entries sorted by date. The admin CRUD at `/admin/changelog` manages entries. This replaced the original hardcoded `@releases` module attribute with database-backed content.

**Why:** Changelogs build trust and transparency. Users want to know what changed. A dynamic changelog means updates are instant — no deploy needed to announce a new feature.

**Files:** `lib/founder_pad/content/resources/changelog_entry.ex`, `lib/founder_pad_web/live/docs/changelog_live.ex`, `lib/founder_pad_web/live/admin/changelog_*.ex`

---

### 11.3 RSS Feeds

**What:** RSS 2.0 feeds for blog posts and changelog entries.

**How:** `FeedController` generates XML feeds at `/blog/feed.xml` and `/changelog/feed.xml`. Each feed queries published items, formats them as `<item>` elements with CDATA-wrapped content, RFC 822 dates, and GUIDs. Includes Atom self-link for feed reader compatibility.

**Why:** RSS lets users and aggregators subscribe to your content. Some users prefer RSS readers over email. It's also useful for content syndication and SEO (search engines crawl feeds).

**Files:** `lib/founder_pad_web/controllers/feed_controller.ex`

---

## 12. SEO Engine

### 12.1 Dynamic Meta Tags

**What:** Every page can have custom title, description, Open Graph, and Twitter Card meta tags.

**How:** `SeoComponents` provides function components: `og_meta/1` (renders og: and twitter: meta tags), `canonical/1` (renders canonical link), `article_json_ld/1` (renders JSON-LD structured data). Blog posts set assigns (`page_title`, `page_description`, `page_image`, `page_url`) which the root layout renders into `<head>`. The root layout has a conditional `<meta name="description">` that renders when `@page_description` is assigned.

**Why:** Meta tags directly impact search rankings and social media sharing. Without proper OG tags, shared links look plain. Without canonical URLs, search engines may penalize duplicate content. JSON-LD helps Google display rich results (article cards, breadcrumbs).

**Files:** `lib/founder_pad_web/components/seo_components.ex`, `lib/founder_pad_web/components/layouts/root.html.heex`

---

### 12.2 SEO Score Checker

**What:** An 8-point SEO checklist that scores each blog post on completeness.

**How:** `SeoScorer.score/1` is a pure function that checks: title length (20-70 chars), meta description (50-160 chars), has excerpt, has featured image, has canonical URL, clean slug (lowercase + hyphens only), body length (50+ words), has OG image. Returns a percentage score and the list of passed/failed checks. The admin blog editor shows the score in real-time as authors edit.

**Why:** Most content creators don't think about SEO while writing. The score gives immediate, actionable feedback — "you're missing a meta description" — without needing an external SEO tool.

**Files:** `lib/founder_pad/content/seo_scorer.ex`

---

### 12.3 Auto-Generated Sitemap

**What:** Dynamic `sitemap.xml` at `/sitemap.xml` listing all public URLs including published blog posts.

**How:** `SitemapController` generates XML by combining static URLs (home, login, register, blog, docs, changelog) with dynamic URLs from published blog posts. Each URL has a changefreq and priority hint for search engines.

**Why:** Sitemaps help search engines discover and index your pages faster. Without one, new blog posts might take weeks to appear in Google.

**Files:** `lib/founder_pad_web/controllers/sitemap_controller.ex`

---

### 12.4 SEO Dashboard

**What:** Admin dashboard at `/admin/seo` showing aggregate SEO health across all blog posts.

**How:** `SeoDashboardLive` queries all posts, calculates their SEO scores, and displays: total posts, average SEO score, count needing improvement (below 70%), and a table of all posts with scores and failed checks. Links to the editor for quick fixes.

**Why:** SEO is an ongoing effort. The dashboard gives admins a bird's-eye view of content health without clicking into each post individually.

**Files:** `lib/founder_pad_web/live/admin/seo_dashboard_live.ex`

---

## 13. Admin Panel

### 13.1 Admin Dashboard

**What:** System overview at `/admin` showing key metrics: total users, organisations, active API keys, feature flags.

**How:** `AdminDashboardLive` queries counts from each domain's resources. Stats are displayed as clickable cards that link to the relevant management page. Protected by the `RequireAdmin` hook which checks `current_user.is_admin`.

**Why:** Admins need a central place to monitor platform health at a glance. Is the user count growing? Are API keys being created? How many feature flags are active?

**Files:** `lib/founder_pad_web/live/admin/admin_dashboard_live.ex`, `lib/founder_pad_web/hooks/require_admin.ex`

---

### 13.2 User Management

**What:** Admin interface to view, search, suspend, and manage all users.

**How:** `UsersLive` at `/admin/users` shows a searchable list of all users with email, name, admin badge, suspended status, and creation date. `UserDetailLive` at `/admin/users/:id` shows full profile info, org memberships, and action buttons: suspend/unsuspend (sets `suspended_at` timestamp), toggle admin status, and impersonate. The `suspend` and `unsuspend` actions on the User resource require `is_admin` policy.

**Why:** Platform operators need to manage users — disable abusive accounts, investigate issues, promote admins. Without this, you'd need direct database access.

**Files:** `lib/founder_pad_web/live/admin/users_live.ex`, `lib/founder_pad_web/live/admin/user_detail_live.ex`

---

### 13.3 User Impersonation

**What:** Admins can view the app as any user — seeing exactly what they see — for debugging and support.

**How:** Session-based: `ImpersonationController.start/2` sets `impersonated_user_id` in the session. The `AssignDefaults` hook checks for this key — if present and the real user is admin, it swaps `current_user` to the impersonated user while preserving `admin_user`. An amber banner at the top shows "Impersonating: [user] | End Impersonation". The stop action clears the session key.

**Why:** When a user reports "I can't see X" or "Y is broken", impersonation lets support staff see the exact same state. It's 10x faster than asking the user for screenshots.

**Files:** `lib/founder_pad_web/controllers/admin/impersonation_controller.ex`, `lib/founder_pad_web/hooks/assign_defaults.ex`, `lib/founder_pad_web/components/layouts/app.html.heex` (banner)

---

## 14. API Key Management

### 14.1 API Key Generation & Storage

**What:** Users generate API keys for programmatic access. Keys have scoped permissions (read, write, admin) and can be revoked.

**How:** The `ApiKey` resource uses SHA-256 hashed storage — the raw key is generated with `:crypto.strong_rand_bytes(32)`, Base64-encoded, prefixed with `fp_`, and shown to the user exactly once. Only the SHA-256 hash is stored in the database (same principle as passwords). The `key_prefix` (first 12 chars) is stored for display purposes. Keys can have expiration dates and are scoped to an organisation.

**Why:** API keys enable programmatic access — users build integrations, automate workflows, and connect to external systems. Hashed storage means a database breach doesn't expose raw keys.

**Files:** `lib/founder_pad/api_keys/resources/api_key.ex`, `lib/founder_pad/api_keys/resources/api_key_usage.ex`

---

### 14.2 API Key Authentication Plug

**What:** Middleware that authenticates API requests using Bearer tokens.

**How:** `ApiKeyAuth` plug extracts the Bearer token from the Authorization header, hashes it with SHA-256, and looks up the matching `ApiKey` by hash (excluding revoked keys). If found, it sets `conn.assigns.api_key` and `conn.assigns.current_organisation`. The `last_used_at` timestamp is updated asynchronously (via `Task.start`) to avoid blocking the request.

**Why:** API authentication is the gateway to programmatic access. The plug pattern means it's automatically applied to all API routes without per-endpoint configuration.

**Files:** `lib/founder_pad_web/plugs/api_key_auth.ex`

---

### 14.3 API Key Management UI

**What:** User-facing page at `/api-keys` to create, view, and revoke API keys.

**How:** `ApiKeysLive` shows a table of the current org's keys with: name, prefix (e.g., `fp_a1B2c3D4`), scopes, last used, creation date, and revoke button. The create form accepts a name and scope checkboxes. After creation, the raw key is displayed in a dismissible banner — this is the only time the user can copy it.

**Why:** Self-service key management reduces support burden. Users can create keys for different environments (staging, production), scope them appropriately, and revoke compromised ones immediately.

**Files:** `lib/founder_pad_web/live/api_keys_live.ex`

---

## 15. GDPR Compliance

### 15.1 Cookie Consent

**What:** Banner asking users to accept/decline analytics and marketing cookies, with consent tracked in the database.

**How:** The `CookieConsent` Ash resource (in the `Privacy` domain) stores: consent_id (anonymous browser ID), analytics (boolean), marketing (boolean), functional (always true), IP address, and user agent. The `CookieConsentController` API endpoint at `POST /api/privacy/cookie-consent` creates the record and sets a response cookie. The consent_id links anonymous consent to a user if they later log in.

**Why:** EU law (GDPR) and ePrivacy Directive require informed consent before setting non-essential cookies. Fines for non-compliance can reach 4% of annual revenue.

**Files:** `lib/founder_pad/privacy/resources/cookie_consent.ex`, `lib/founder_pad_web/controllers/cookie_consent_controller.ex`

---

### 15.2 Data Export (Right to Portability)

**What:** Users can request a full export of their data as a JSON file.

**How:** The `DataExportRequest` resource tracks the request lifecycle: pending → processing → completed → expired. When a user requests an export, an Oban `DataExportWorker` job is enqueued. The worker collects user profile data, preferences, and email preferences into a JSON file, saves it to the server, and marks the request as completed with a 48-hour download link.

**Why:** GDPR Article 20 gives EU users the right to receive their personal data in a machine-readable format. This feature makes you compliant out of the box.

**Files:** `lib/founder_pad/privacy/resources/data_export_request.ex`, `lib/founder_pad/privacy/workers/data_export_worker.ex`

---

### 15.3 Account Deletion (Right to Erasure)

**What:** Users can request account deletion with a 30-day grace period before permanent removal.

**How:** The `DeletionRequest` resource tracks the full lifecycle: pending → confirmed → soft_deleted → hard_deleted (or cancelled). On request, a confirmation token is generated and emailed. After confirmation, the user is immediately soft-deleted (suspended, email anonymized). A daily Oban cron job (`HardDeleteWorker` at 3am UTC) checks for requests past the 30-day `hard_delete_after` date and cascades the permanent deletion. During the grace period, an admin can cancel the deletion.

**Why:** GDPR Article 17 gives EU users the right to have their data erased. The 30-day grace period protects against accidental deletion while still complying with the law.

**Files:** `lib/founder_pad/privacy/resources/deletion_request.ex`, `lib/founder_pad/privacy/workers/hard_delete_worker.ex`

---

### 15.4 Email Unsubscribe

**What:** One-click unsubscribe from any email category via a link in the email footer.

**How:** `EmailLayout.unsubscribe_url/2` generates a signed Phoenix token encoding `{user_id, category}`. The `UnsubscribeController` at `GET /unsubscribe/:token` verifies the token (30-day validity), updates the user's `email_preferences` map to set that category to `false`, and renders a confirmation page. Every email includes this link in the footer.

**Why:** CAN-SPAM (US) and GDPR (EU) require easy unsubscribe mechanisms. One-click compliance means no "are you sure?" pages — the GET request immediately unsubscribes.

**Files:** `lib/founder_pad_web/controllers/unsubscribe_controller.ex`, `lib/founder_pad/notifications/email_layout.ex` (`unsubscribe_url/2`)

---

### 15.5 Privacy Policy & Terms

**What:** Static pages at `/privacy` and `/terms` with GDPR-compliant privacy policy and terms of service.

**How:** `PrivacyLive` and `TermsLive` are standalone LiveViews with `layout: false`. They contain the legal text covering: data collection, usage, GDPR rights (access, deletion, portability, opt-out), cookie policy, and contact information. Links are in the app sidebar and footer.

**Why:** Every SaaS needs a privacy policy and terms of service. GDPR requires you to clearly explain what data you collect and how you use it. Having these pages built-in means buyers just customize the text.

**Files:** `lib/founder_pad_web/live/privacy_live.ex`, `lib/founder_pad_web/live/terms_live.ex`

---

## 16. Help Center

### 16.1 Help Center with Full-Text Search

**What:** Searchable knowledge base with categorized help articles at `/help`.

**How:** The `HelpCenter` domain has 3 resources: Category (name, slug, icon, position), Article (title, slug, body, excerpt, help_context_key, status, position), ContactRequest (name, email, subject, message). Articles use PostgreSQL full-text search via a `tsvector` generated column with GIN index — title is weighted highest (A), excerpt medium (B), body lowest (C). The `:search` read action uses `plainto_tsquery` for natural language queries and `ts_rank` for relevance ranking.

Public pages: `/help` (category grid + search bar), `/help/search?q=...` (search results), `/help/:category/:slug` (article), `/help/contact` (support form).

**Why:** Help centers reduce support tickets by 20-30%. Users prefer finding answers themselves at any hour. Full-text search means they can type natural questions ("how do I set up billing?") and get relevant results with stemming (billing matches billed).

**Files:** `lib/founder_pad/help_center/` (domain + resources), `lib/founder_pad_web/live/help/` (public pages)

---

### 16.2 Contextual Help Links

**What:** A `<.help_link context="agents.create" />` component that renders a `?` icon linking to relevant help content from anywhere in the app.

**How:** The `help_link/1` function component in CoreComponents renders a small help icon that links to `/help/search?q={context}`. Articles have a `help_context_key` attribute (e.g., "agents.create", "billing.plans") that can be used for exact matching in the future.

**Why:** Contextual help means users don't have to leave what they're doing to search for help. The answer is one click away, right next to the feature they're using.

**Files:** `lib/founder_pad_web/components/core_components.ex` (`help_link/1`)

---

## 17. Error Pages

### 17.1 Branded Error Pages

**What:** Custom-designed error pages for 404, 500, 429, 402, and 503 status codes.

**How:** Each error page is a standalone `.html.heex` template in `lib/founder_pad_web/controllers/error_html/`. They use inline CSS (no external dependencies), Material Symbols icons, and the app's dark theme. Each page has contextual messaging and relevant CTAs:
- **404** — "Lost in the void." + search help link + back button
- **500** — "Something broke." + contact support link
- **429** — "Too many requests." + retry message
- **402** — "Upgrade required." + billing CTA
- **503** — "We'll be right back." (maintenance)

**Why:** Default error pages look unprofessional and provide no guidance. Branded pages maintain trust, help users recover, and can even reduce support tickets (the 404 page links to the help center).

**Files:** `lib/founder_pad_web/controllers/error_html/*.html.heex`

---

### 17.2 Maintenance Mode

**What:** Toggle the entire app offline with a branded 503 page.

**How:** `MaintenanceMode` plug sits in the endpoint pipeline (after session, before router). It checks two sources: the `MAINTENANCE_MODE` environment variable (for when the DB is down) and the `maintenance_mode` feature flag (for planned maintenance via admin panel). Admin bypass is available via a `maintenance_bypass` cookie — set it to the value of `:maintenance_bypass_secret` in config. Static files (CSS, JS, images) are still served during maintenance.

**Why:** Every SaaS needs planned downtime eventually — database migrations, infrastructure changes, etc. A maintenance mode that's toggleable without a deploy (via feature flag) and works even when the DB is down (via env var) covers all scenarios.

**Files:** `lib/founder_pad_web/plugs/maintenance_mode.ex`, `lib/founder_pad_web/endpoint.ex`

---

## 18. Status Page

### 18.1 Public Status Page

**What:** Public page at `/status` showing system component health and incident history.

**How:** The `System` domain has an `Incident` resource with: title, description, status (investigating/identified/monitoring/resolved), severity (minor/major/critical), affected_components array, resolved_at. `StatusLive` shows system components (API, Dashboard, AI Agents, Billing, Email) all as "Operational" by default, with active incidents displayed prominently and recent incident history below. Admin CRUD at `/admin/incidents` manages incidents.

**Why:** Status pages build trust with customers. When something breaks, a transparent status page reduces panic and support tickets. Enterprise customers often require a status page for SLA monitoring.

**Files:** `lib/founder_pad/system/resources/incident.ex`, `lib/founder_pad/system/system.ex`, `lib/founder_pad_web/live/status_live.ex`, `lib/founder_pad_web/live/admin/incidents_live.ex`

---

## 19. Global Search (Cmd+K)

### 19.1 Command Palette

**What:** Press Cmd+K (or Ctrl+K) to open a search modal that searches across pages, agents, blog posts, and help articles.

**How:** The `CommandPalette` JavaScript hook listens for the keyboard shortcut, then builds a modal overlay. On each keystroke (debounced 150ms), it fetches results from `GET /api/search?q=...`. The `SearchController` searches: static pages (Dashboard, Agents, Billing, etc. by name match), published blog posts (ILIKE on title), and help articles (full-text search). Results are grouped by type (Pages, Blog, Help) and displayed with icons. Arrow keys navigate results, Enter opens the selected one, Escape closes the modal.

**Why:** Power users expect Cmd+K in modern SaaS (Linear, Notion, Slack). It's the fastest way to navigate the app — no clicking through menus. The search-based navigation also helps users discover features they didn't know existed.

**Files:** `assets/js/hooks/command_palette.js`, `lib/founder_pad_web/controllers/search_controller.ex`

---

## 20. Referral System

### 20.1 Referral Codes & Rewards

**What:** Users get a unique referral code (e.g., `FP-A1B2C3D4`) to share. When someone signs up using their code, both get a reward.

**How:** The `Referrals` domain has a `Referral` resource with: code (auto-generated, unique), referrer_id, referred_id, status (pending/completed/expired), reward_type ("credit"), reward_amount_cents (default 500 = $5). The `ReferralsLive` page at `/referrals` shows the user's code, a shareable link, stats (total referrals, completed, earned), and a referral history table. The `:complete` action marks a referral as completed when the referred user takes a qualifying action.

**Why:** Referral programs are the cheapest acquisition channel. Users who come through referrals have 37% higher retention (according to Deloitte). A built-in referral system means buyers don't need to integrate a third-party tool like ReferralCandy.

**Files:** `lib/founder_pad/referrals/resources/referral.ex`, `lib/founder_pad/referrals/referrals.ex`, `lib/founder_pad_web/live/referrals_live.ex`

---

## 21. Embeddable Chat Widget

### 21.1 Script Tag Embed

**What:** A `<script>` tag that adds a floating chat bubble to any external website, powered by a FounderPad AI agent.

**How:** `WidgetController.script/2` at `/widget/embed/:agent_id` serves JavaScript that creates a floating button (bottom-right, FounderPad purple) and an iframe containing the chat UI at `/widget/chat/:agent_id`. The chat UI is a self-contained HTML page with a message list, input field, and send button. In the current version, it responds with a demo message — in production, it would call the agent's API.

The `WidgetConfigLive` page at `/agents/:id/widget` shows the embed code snippet users can copy, a live preview, and customization options (color, position).

**Why:** Embeddable chat widgets let users deploy their AI agents to customer-facing websites. This opens an entirely new use case beyond internal tooling — customer support bots, sales assistants, and product guides.

**Files:** `lib/founder_pad_web/controllers/widget_controller.ex`, `lib/founder_pad_web/live/widget_config_live.ex`

---

## 22. Real-Time Collaboration

### 22.1 Phoenix Presence

**What:** When multiple users view the same agent, they see who else is online — colored avatar circles showing team members currently looking at or editing the agent.

**How:** `FounderPadWeb.Presence` is a Phoenix Presence module backed by Phoenix PubSub. On mount in `AgentDetailLive`, the user is tracked in the `"agent:{agent_id}"` topic with metadata (name, avatar_url, joined_at). The Presence system automatically handles joins, leaves, and network disconnections. `handle_info({:presence_diff, ...})` updates the list of present users. The UI shows colored initials circles for each online user.

**Why:** Collaboration awareness prevents conflicts — if you see a teammate is already editing an agent, you know to coordinate. It also creates a sense of team activity and makes the product feel alive. Phoenix Presence uses CRDTs, so it works across distributed nodes without a central database.

**Files:** `lib/founder_pad_web/live/presence.ex`, `lib/founder_pad_web/live/agent_detail_live.ex` (modified), `assets/js/hooks/collaboration.js`

---

## 23. Onboarding

### 23.1 Multi-Step Wizard

**What:** A guided setup flow that walks new users through: naming their organisation, inviting team members, selecting an agent template, and reviewing their setup.

**How:** `OnboardingLive` is a multi-step LiveView. Each step stores data in socket assigns. Skip-if-done detection checks whether the user already has an org membership — if so, they're redirected to the dashboard. An incomplete onboarding shows a banner on the dashboard prompting the user to finish.

**Why:** First-time setup is the highest-friction moment. Without onboarding, users land on an empty dashboard and don't know what to do. The wizard guides them through the critical first actions that predict long-term retention.

**Files:** `lib/founder_pad_web/live/onboarding_live.ex`

---

## 24. Settings & Preferences

### 24.1 User Settings

**What:** Profile editing (name, avatar), password change, theme preferences (dark/light, compact, high contrast), and email notification preferences.

**How:** `SettingsLive` at `/settings` has multiple sections: profile (name + avatar upload via LiveView `allow_upload/3`), password change (with current password verification), appearance (theme, compact UI, high contrast — stored in `preferences` map and persisted to localStorage via JS hooks), and email preferences (per-category toggles stored in `email_preferences` map).

**Why:** Users need control over their experience. Theme preferences improve accessibility (high contrast for low vision). Email preferences ensure compliance (GDPR/CAN-SPAM). Avatar upload personalizes the team experience.

**Files:** `lib/founder_pad_web/live/settings_live.ex`, `assets/js/hooks/theme_toggle.js`, `assets/js/hooks/theme_settings.js`

---

## 25. Documentation & Public Pages

### 25.1 Landing Page

**What:** Marketing page at `/` with hero section, feature highlights, pricing tiers, testimonials, and CTAs.

**How:** `LandingLive` is a large standalone LiveView with the full marketing page. It showcases the product's value proposition and drives signups.

**Why:** The landing page is your storefront. It converts visitors into users.

**Files:** `lib/founder_pad_web/live/landing_live.ex`

---

### 25.2 Documentation Hub

**What:** Documentation pages at `/docs`, `/docs/api`, and `/docs/changelog`.

**How:** `DocsLive` provides a documentation hub with guides. `ApiSpecsLive` shows API documentation. `ChangelogLive` shows the product changelog (now DB-backed).

**Why:** Documentation reduces support burden and helps developers integrate with the API.

**Files:** `lib/founder_pad_web/live/docs/`

---

## 26. Infrastructure

### 26.1 Seed Data

**What:** A comprehensive seed script that populates the database with demo content: admin user, demo user, organisation, feature flags, blog posts, changelog entries, help articles, and agent templates.

**How:** `priv/repo/seeds.exs` uses direct Ecto inserts for users (bypassing AshAuthentication hooks that require Oban), and Ash changesets with `authorize?: false` for all other resources. Run with `mix run priv/repo/seeds.exs`.

**Why:** Buyers need to see the product working immediately after setup. Seed data means they can log in, browse the blog, search help articles, and explore agent templates without creating everything from scratch.

**Files:** `priv/repo/seeds.exs`

---

### 26.2 Setup Guide

**What:** Comprehensive setup documentation covering quick start, environment variables, feature overview, deployment, and customization.

**How:** `docs/SETUP.md` — a Markdown file covering everything a buyer needs to get FounderPad running: dependency installation, database setup, seeding, server start, all env vars organized by feature, deployment to Fly.io and Docker, and customization steps.

**Why:** Clear setup docs reduce the time from "I bought this" to "it's running" from hours to minutes. Every question the docs answer is a support ticket avoided.

**Files:** `docs/SETUP.md`

---

## Technical Architecture Summary

| Layer | Technology |
|-------|-----------|
| Language | Elixir 1.17+ |
| Framework | Phoenix 1.8 + LiveView 1.0 |
| Domain Layer | Ash Framework 3.x (DDD) |
| Database | PostgreSQL 15+ (AshPostgres) |
| Auth | AshAuthentication 4.0 |
| Background Jobs | Oban 2.18 |
| Payments | Stripe (stripity_stripe 3.0) |
| Email | Swoosh + Resend |
| AI | Anthropic + OpenAI (Req HTTP) |
| Rate Limiting | Hammer 7.0 |
| CSS | TailwindCSS 4.x + daisyUI |
| Icons | Material Symbols |
| JS Build | esbuild |
| Deployment | Fly.io + Docker |

| Metric | Count |
|--------|-------|
| Ash Domains | 12 |
| Ash Resources | ~35 |
| LiveViews | ~40 |
| Tests | 484 |
| Features | 70 |
