# GhanaTrust — Working Roadmap

Grounded in the **current build state** (branch `feat/ghanatrust-compliance-mvp`,
565 tests passing). Maps the original `ROADMAP_SPRINTS.md` plan to what exists, then
defines the next sprints with a verifiable **Definition of Done (DoD)** each.

Legend: ✅ done · 🟡 partial · ⬜ not started

---

## Where we are (original Sprints 1–10)

| Original sprint | Status | Notes |
|---|---|---|
| 1 Foundation (Phoenix/Ash/PG/CI) | ✅ | Inherited from founder-pad base |
| 2 Accounts/Tenants/RBAC | ✅ | Inherited (orgs, memberships, auth, MFA) |
| 3 API keys + test/live mode | ✅ | Inherited + added `mode` attribute |
| 4 Individual verification API | ✅ | Resource, Sandbox provider, `/v1` create/retrieve, lifecycle |
| 5 Consent + audit | ✅ | `ConsentReceipt`, audit events on lifecycle |
| 6 Dashboard MVP | 🟡 | Verifications list/detail + Review Queue ✅; consent viewer + usage ⬜ |
| 7 Webhooks | ✅ | Signed + Oban retry (inherited) wired to verification events |
| 8 Manual review | ✅ | `ReviewCase`/`ReviewNote`, reasoned/audited decisions, queue UI |
| 9 Security hardening | 🟡 | Rate limiting ✅, log redaction ✅, headers ✅; encryption ⬜, audit-coverage tests ⬜ |
| 10 Pilot readiness | 🟡 | Sandbox fixtures ✅, docs ✅; OpenAPI ⬜, onboarding guide ⬜, deploy review ⬜ |

**Release gate: Alpha (internal, sandbox-only) is met.** Next target: **Private Beta**.

---

## Sprint A — Developer experience & pilot polish  → *Private Beta gate*

Close out Sprints 6/10. Make a developer self-serve in sandbox in <30 min.

- ⬜ OpenAPI 3 spec for `/v1` + a served `/docs/api` page (validate with a linter)
- ⬜ `Idempotency-Key` header store (resource) — replace external_id-only dedup; `duplicate_idempotency_key` error
- ⬜ Consent viewer + usage summary LiveViews (finish dashboard)
- ⬜ API quickstart in `docs/` (curl walkthrough using sandbox fixtures)
- ⬜ Deploy review: Dockerfile/fly.toml/runtime.exs, health check, CI green

**DoD:** OpenAPI validates; a new dev follows the quickstart to a passing sandbox
verification without help; `mix test` + CI green; consent + usage visible in dashboard.

## Sprint B — Evidence & liveness

- ⬜ `EvidenceItem` resource + **signed upload-URL abstraction** (object-storage behaviour; local/sandbox adapter)
- ⬜ `POST /v1/individual_verifications/:id/evidence_uploads`
- ⬜ `LivenessProvider` behaviour + Sandbox; record liveness status on the verification
- ⬜ Mobile-friendly field capture (consent + selfie) — PWA path (story M2)

**DoD:** evidence uploaded via signed URL; **raw images never hit the DB**; liveness
status recorded and shown; checksum + expiry tracked.

## Sprint C — KYB (business verification)

- ⬜ `BusinessVerification` (registered_name, `registration_number_hash`, `tin_hash`, risk_level)
- ⬜ `KybProvider` behaviour + Sandbox fixtures
- ⬜ `POST/GET /v1/business_verifications`
- ⬜ KYB review cases (reuse `ReviewCase` subject_type) + dashboard surfacing

**DoD:** KYB check end-to-end in sandbox; tenant-isolated; audited; webhooked; review
case opens on `requires_review`.

## Sprint D — AML screening

- ⬜ `AmlScreen` (sanctions/PEP/adverse_media, match_count, highest_confidence)
- ⬜ `AmlProvider` behaviour + Sandbox
- ⬜ Wire `options.run_aml_screen`; `possible_match` → review case (human-in-the-loop)
- ⬜ Risk engine `rules_v2` incorporates the AML signal

**DoD:** AML screen runs in sandbox; possible matches route to review; **no automated
final AML decision without human review** (per MVP_SCOPE); confirmed decisions audited.

## Sprint E — Hardening II & operations

- ⬜ **Cloak** column encryption for card/PII at rest → enables true async live provider via Oban
- ⬜ Provider-health + failed-job internal ops console (story O1)
- ⬜ Audit-coverage tests (assert *every* sensitive action emits an event)
- ⬜ `gt_test_`/`gt_live_` key prefixes + granular scopes (`verifications:write`, …)
- ⬜ Retention jobs (evidence / webhook-payload cleanup) per policy

**DoD:** PII encrypted at rest (verified); ops console shows provider + Oban health;
retention jobs scheduled; audit-coverage test suite green.

## Sprint F — Live pilot readiness  → *Live Pilot gate*

- ⬜ First **live `IdentityProvider`** adapter behind a config/feature flag (disabled until contract)
- ⬜ Billing usage events wired per verification (metering → existing Billing domain)
- ⬜ DPA/terms acceptance tracking per tenant
- ⬜ Telemetry dashboards + backup/restore runbook validation

**DoD:** live mode behind a flag with the same tests as sandbox; per-check usage metered;
pilot tenant onboarded end-to-end; runbook rehearsed.

---

## Cross-cutting definition of done (every sprint)

1. Test-first (red → green); `mix test --seed 0` stays green.
2. New sensitive actions emit audit events and redact PII in logs.
3. Tenant isolation proven by a test for any new tenant-scoped resource.
4. New `/v1` surface documented in `docs/GHANATRUST.md` + OpenAPI.
5. No raw biometric/identity data persisted unless encrypted + consented.

## Suggested order & sizing

`A (1 wk) → B (1–2 wk) → C (1 wk) → D (1–2 wk) → E (1–2 wk) → F (2 wk)`.
A unlocks design-partner onboarding; B–D complete the product surface; E–F unlock the
live pilot. Run **Phase 0 validation in parallel** (interviews + NIA route + legal),
since the live gate depends on it, not on code.
