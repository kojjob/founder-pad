# OAuth, GDPR & Email Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add OAuth social login (Google, GitHub, Microsoft), GDPR compliance (cookie consent, data export, account deletion), and branded transactional email templates with unsubscribe.

**Architecture:** OAuth via AshAuthentication's built-in strategies with a SocialIdentity resource for account linking. New `Privacy` Ash domain for consent and deletion tracking. Shared `EmailLayout` wrapper for all emails. Oban workers for drip sequences and data exports.

**Tech Stack:** AshAuthentication (OAuth2/Assent), Ash Framework 3.x, Swoosh, Oban, Phoenix LiveView

---

## Task 1: Email Preferences on User + EmailLayout Wrapper

Add `email_preferences` map to User. Create shared EmailLayout module for branded emails. Refactor existing AuthMailer to use it.

Commit: `feat(email): add email_preferences to User and shared EmailLayout wrapper`

## Task 2: Privacy Domain (CookieConsent, DataExportRequest, DeletionRequest)

Create Privacy Ash domain with 3 resources for GDPR tracking.

Commit: `feat(privacy): add Privacy domain with consent, export, and deletion resources`

## Task 3: Privacy Tests + Cookie Consent Banner

Tests for privacy resources. Cookie consent API endpoint + banner component.

Commit: `feat(privacy): add cookie consent banner and privacy tests`

## Task 4: Data Export + Account Deletion Workers

Oban workers for GDPR data export (ZIP) and account deletion (30-day soft delete pipeline).

Commit: `feat(privacy): add data export and account deletion Oban workers`

## Task 5: Unsubscribe Flow + Email Preferences UI

One-click unsubscribe controller with signed tokens. Email preferences panel in Settings.

Commit: `feat(email): add unsubscribe flow and email preferences in Settings`

## Task 6: Onboarding + Digest Email Templates

Welcome email, onboarding drip (day 1, 3, 7), weekly digest worker. All use EmailLayout.

Commit: `feat(email): add onboarding drip and weekly digest email templates`

## Task 7: OAuth Social Login (Google, GitHub, Microsoft)

SocialIdentity resource, OAuth strategies on User, callback controller, Connected Accounts in Settings.

Commit: `feat(auth): add OAuth social login with Google, GitHub, Microsoft`

## Task 8: Privacy Pages + Settings Integration + Final

Privacy policy page, terms page, data export/deletion in Settings, nav updates.

Commit: `feat(privacy): add privacy pages, settings integration, and nav updates`

---

## Verification

1. `mix test` — all pass
2. Visit `/settings` — email preferences panel, connected accounts, data export/delete buttons
3. One-click unsubscribe via email link
4. Cookie consent banner on first visit
5. OAuth buttons on login page (require env vars for actual provider testing)
