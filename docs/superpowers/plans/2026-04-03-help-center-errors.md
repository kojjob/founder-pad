# Help Center & Error Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a searchable Help Center with PostgreSQL full-text search, in-app contextual help links, polished error pages (404/500/429/402/503), and a maintenance mode plug toggled via feature flags.

**Architecture:** New `FounderPad.HelpCenter` Ash domain with Category, Article, and ContactRequest resources. Articles use PostgreSQL `tsvector` with GIN index for ranked full-text search. Public pages at `/help/*` follow the existing DocsLive pattern (layout: false). Error pages are standalone HTML (no JS deps). Maintenance mode is a plug in the endpoint pipeline, toggled via feature flag or env var.

**Tech Stack:** Ash Framework 3.x, Phoenix LiveView 1.0, PostgreSQL full-text search, TailwindCSS

---

## File Structure

### New Files
```
lib/founder_pad/help_center/
  help_center.ex                              # Ash Domain
  resources/
    category.ex                               # Help category
    article.ex                                # Help article with tsvector
    contact_request.ex                        # Contact support form

lib/founder_pad_web/live/help/
  help_index_live.ex                          # /help — categories + search
  help_article_live.ex                        # /help/:category/:slug
  help_search_live.ex                         # /help/search
  help_contact_live.ex                        # /help/contact

lib/founder_pad_web/live/admin/help/
  help_articles_live.ex                       # /admin/help — article CRUD
  help_article_editor_live.ex                 # /admin/help/new, /admin/help/:id/edit

lib/founder_pad_web/plugs/
  maintenance_mode.ex                         # Endpoint plug

lib/founder_pad_web/controllers/error_html/
  429.html.heex                               # Rate limit
  402.html.heex                               # Subscription required
  503.html.heex                               # Maintenance

test/founder_pad/help_center/
  article_test.exs

test/founder_pad_web/live/help/
  help_index_live_test.exs

test/founder_pad_web/plugs/
  maintenance_mode_test.exs
```

### Modified Files
```
config/config.exs                             # Register HelpCenter domain
lib/founder_pad_web/router.ex                 # Help routes
lib/founder_pad_web/endpoint.ex               # MaintenanceMode plug
lib/founder_pad_web/components/core_components.ex  # help_link component
lib/founder_pad_web/components/layouts/app.html.heex  # Help nav link
lib/founder_pad_web/controllers/error_html/404.html.heex  # Enhanced
lib/founder_pad_web/controllers/error_html/500.html.heex  # Enhanced
test/support/factory.ex                       # Help center factories
```

---

## Task 1: HelpCenter Domain + Resources

Create the Ash domain with Category, Article (with full-text search), and ContactRequest resources. Generate migration with tsvector column and GIN index.

Commit: `feat(help-center): add HelpCenter domain with Category, Article, ContactRequest resources`

## Task 2: HelpCenter Tests + Factories

Write unit tests for article creation, search, category CRUD. Add factory helpers.

Commit: `test(help-center): add unit tests and factories for help center resources`

## Task 3: Help Center Routes + Public LiveViews

Create public help pages: HelpIndexLive (categories grid + search), HelpArticleLive (single article), HelpSearchLive (search results), HelpContactLive (contact form). Add routes. Follow DocsLive pattern (layout: false).

Commit: `feat(help-center): add public help center LiveViews`

## Task 4: Admin Help CRUD

Create admin LiveViews for managing help articles and categories. Add routes to admin live_session.

Commit: `feat(help-center): add admin help article management`

## Task 5: Error Pages + Maintenance Mode

Create 429/402/503 error templates. Enhance existing 404/500 with help links. Create MaintenanceMode plug. Add to endpoint. Add `help_link` component to CoreComponents. Update app nav.

Commit: `feat(help-center): add error pages, maintenance mode, and help_link component`

---

## Verification

1. `mix test` — all pass
2. Visit `/help` — categories and search
3. Visit `/admin/help` — create/edit articles
4. Visit `/help/search?q=billing` — full-text search results
5. Trigger 404 — branded page with help links
6. Enable maintenance_mode flag — 503 page served
