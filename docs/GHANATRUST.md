# GhanaTrust API — Compliance Layer

GhanaTrust is a Ghana-first KYC/KYB/AML/consent/audit API. This document covers the
**compliance domain** built on top of the FounderPad SaaS platform (auth, multi-tenant
orgs, API keys, webhooks, audit, billing are inherited from the base platform).

> Not legal advice. Confirm NIA/verification access, Data Protection Commission
> registration, AML obligations and BoG positioning with qualified Ghanaian experts
> before processing live personal data. Live identity verification stays **disabled**
> until an approved provider route exists (ADR-003).

## What's implemented

| Capability | Module(s) |
|---|---|
| Consent receipts (immutable-except-status) | `FounderPad.Compliance.ConsentReceipt` |
| Individual identity verification | `FounderPad.Compliance.IndividualVerification` |
| Identity provider seam + sandbox | `FounderPad.Compliance.Providers.{IdentityProvider, Sandbox}` |
| Risk scoring (rules_v1, explainable) | `FounderPad.Compliance.Risk` |
| Verification orchestration | `FounderPad.Compliance.Verifications` |
| Manual review queue | `FounderPad.Compliance.{ReviewCase, ReviewNote}` |
| Public REST API | `FounderPadWeb.Api.V1.IndividualVerificationController` |
| Audit + webhooks on lifecycle | wired via `FounderPad.Audit` / `FounderPad.Webhooks` |

## Security invariants

- **Raw Ghana Card / phone numbers are never stored.** The create action takes them as
  transient arguments, hashes (SHA-256) and persists only `*_hash` columns.
- **Consent before live processing.** `:live` verifications cannot be created without an
  `:active` `ConsentReceipt` — enforced at the data layer, no code path bypasses it.
- **Tenant isolation.** Every record is `organisation_id`-scoped; the API `show` endpoint
  returns 404 across tenants.
- **Immutable audit.** Every verification create/complete and consent capture emits an
  append-only `AuditLog` event with actor (API key), IP, user agent and request id.
- **Mode separation.** API keys carry `:test`/`:live` mode; verifications inherit it.

## Public API (`/v1`)

Machine-readable contract: **`GET /v1/openapi.json`** (OpenAPI 3, public, no key) —
load it into Swagger UI / Redoc / Stoplight or generate clients from it.


Authenticate with `Authorization: Bearer <api_key>`. The key's scopes gate access
(`:write` to create, `:read` to retrieve; `:admin` implies both). The key's mode
(`test`/`live`) sets the verification mode.

### Create

```http
POST /v1/individual_verifications
Authorization: Bearer fp_xxx
Content-Type: application/json

{
  "external_id": "customer_123",
  "person": {
    "ghana_card_number": "GHA-TEST-VERIFIED-1",
    "first_name": "Ama",
    "last_name": "Mensah",
    "date_of_birth": "1995-04-12",
    "phone_number": "+233241234567"
  },
  "consent": {                      // required for live mode
    "purpose": "customer_onboarding",
    "channel": "api",
    "accepted_at": "2026-06-17T12:00:00Z",
    "privacy_notice_version": "2026-01"
  }
}
```

`201` → `{ id, status, mode, external_id, created_at, links.self }`.
Re-POSTing the same `external_id` for a tenant returns the existing check (`200`).

**Idempotency.** Send an `Idempotency-Key: <unique>` header on writes. A retry with the
same key and body replays the original response (no duplicate work, no re-fired
webhooks). The same key with a different body returns `409 duplicate_idempotency_key`.

### Retrieve

```http
GET /v1/individual_verifications/{id}
```

Returns status, `identity` (verified/match_level/provider_reference), `risk`
(level/score/reason_codes), `consent_receipt_id` and timestamps.

### Sandbox fixtures (deterministic)

| Ghana Card number | Outcome |
|---|---|
| `GHA-TEST-VERIFIED-1` | `verified`, low risk |
| `GHA-TEST-REVIEW-1` | `requires_review` (opens a review case) |
| `GHA-TEST-FAILED-1` | `failed`, high risk |
| `GHA-TEST-PROVIDER-DOWN` | provider outage → check left unfinished |
| any other non-empty value | deterministic `verified` |

### Error codes

`authentication_failed` (401), `permission_denied` (403), `verification_not_found`
(404), `validation_failed` / `consent_required` (422), `duplicate_idempotency_key`
(409). Envelope: `{ "error": { "code", "message", "request_id" } }`.

## Webhooks

When a check reaches a terminal state, a signed delivery (Oban, with retry) is enqueued
to every active org webhook subscribed to the event:

- `individual_verification.completed` — verified/failed
- `individual_verification.requires_review` — needs manual review

## Running locally

```bash
mix setup                 # deps + assets
mix ash.setup             # create DB + run migrations
mix run priv/repo/ghanatrust_seeds.exs   # demo tenant + sandbox key
mix phx.server
mix test                  # full suite (run with --seed 0 for determinism)
```

## Provider configuration

The identity provider is swappable by config (defaults to sandbox):

```elixir
config :founder_pad, :identity_provider, FounderPad.Compliance.Providers.Sandbox
```

A live provider implements the `FounderPad.Compliance.Providers.IdentityProvider`
behaviour and is enabled only once an approved NIA/partner route and encrypted-at-rest
PII handling (planned) are in place.

## Remaining (not yet built)

- LiveView dashboard for verifications, consent and the review queue (review-case
  decision UI, plus decision-side audit/webhook emission).
- Business verification (KYB), AML screening and evidence upload (signed URLs).
- Encrypted-at-rest card storage (Cloak) to enable true async live provider calls.
- `gt_test_`/`gt_live_` key prefixes and granular `verifications:write` scopes.
- Internal ops console (provider health, failed jobs).
