# FounderPad Production Features — TODO

## Overview
10 features across 4 sub-projects. Each sub-project is a separate branch and PR.

**Design Spec:** `docs/superpowers/specs/2026-04-02-production-features-design.md`

---

## Sub-project 1: Content Engine (Blog CMS + SEO + Changelog)
**Branch:** `feature/content-engine`
**Plan:** `docs/superpowers/plans/2026-04-02-content-engine.md`

- [x] Task 1: Add `is_admin` to User resource
- [x] Task 2: Create Ash changes (GenerateSlug + CalculateReadingTime)
- [x] Task 3: Create Content domain resources (Post, Category, Tag, ChangelogEntry)
- [x] Task 4: Content domain unit tests
- [x] Task 5: SEO scorer
- [x] Task 6: RequireAdmin hook + admin routes
- [x] Task 7: Tiptap WYSIWYG editor hook
- [x] Task 8: SEO components (meta tags, JSON-LD)
- [x] Task 9: Blog components (cards, badges)
- [x] Task 10: Public blog LiveViews (index, post, category, tag)
- [x] Task 11: Admin blog LiveViews (list, editor, categories, tags)
- [x] Task 12: Admin changelog + refactor public changelog to DB
- [x] Task 13: RSS feed controller + sitemap extension
- [x] Task 14: Oban scheduled publishing worker
- [x] Task 15: SEO dashboard + admin nav + final integration

---

## Sub-project 2: Admin & API Infrastructure
**Branch:** `feature/admin-api-keys`
**Plan:** `docs/superpowers/plans/2026-04-03-admin-api-keys.md`
**Depends on:** Sub-project 1 (is_admin field) ✅

- [x] Task 1: Add suspended_at to User + suspend/unsuspend actions
- [x] Task 2: ApiKeys domain + resources (ApiKey, ApiKeyUsage)
- [x] Task 3: ApiKey tests + factories
- [x] Task 4: ApiKeyAuth plug
- [x] Task 5: Admin routes + dashboard
- [x] Task 6: Admin users LiveView (list, detail, suspend)
- [x] Task 7: Admin organisations + subscriptions LiveViews
- [x] Task 8: Admin feature flags LiveView
- [x] Task 9: User-facing API keys LiveView
- [x] Task 10: Impersonation + admin nav + final integration

---

## Sub-project 3: Auth, Privacy & Email
**Branch:** `feature/oauth-gdpr-email`
**Independent** — can run in parallel with Sub-project 2

- [x] OAuth2 strategies (Google, GitHub, Microsoft)
- [x] SocialIdentity resource + account linking
- [x] Connected Accounts UI in Settings
- [x] Privacy domain (CookieConsent, DataExportRequest, DeletionRequest)
- [x] Cookie consent banner
- [x] Data export pipeline (Oban worker)
- [x] Account deletion pipeline (soft delete → hard delete)
- [x] Shared EmailLayout wrapper
- [x] Onboarding drip emails (day 1, 3, 7)
- [x] Weekly digest worker
- [x] Billing alert emails
- [x] Unsubscribe flow + email preferences

---

## Sub-project 4: Support & Polish
**Branch:** `feature/help-center-errors`
**Depends on:** Sub-project 2 (admin layout)

- [ ] HelpCenter domain (Category, Article, ContactRequest)
- [ ] PostgreSQL full-text search (tsvector + GIN)
- [ ] Public help pages (/help/*)
- [ ] In-app `help_link` component
- [ ] Contact support form
- [ ] Admin help CRUD
- [ ] Enhanced error pages (404, 500)
- [ ] New error pages (429, 402, 503)
- [ ] Maintenance mode plug + feature flag
