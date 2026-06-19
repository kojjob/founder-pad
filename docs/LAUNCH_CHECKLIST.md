# GhanaTrust — Launch Readiness Checklist

Tracks the path from **Alpha (sandbox-only, internal) — already met** through **Private
Beta** to **Live Pilot**. Engineering items marked ✅ are built and tested on
`feat/ghanatrust-compliance-mvp`; ⬜ items are **yours to procure** (business/legal/ops)
— they are the real launch blockers now, not code.

> Not legal advice. Confirm everything below with qualified Ghanaian legal/compliance
> counsel and the relevant authorities before processing live personal data.

---

## Gate 1 — Alpha ✅ (met)

Internal users, sandbox only.

- ✅ Sandbox KYC/KYB/AML, consent, evidence, liveness, review queue
- ✅ Public `/v1` API (create/list/retrieve/evidence/webhooks) + OpenAPI + quickstart
- ✅ Audit trail, log redaction, rate limiting, retention jobs, usage metering
- ✅ Dashboard, ops/provider-health view, `/health`, CI green

## Gate 2 — Private Beta (design partners, sandbox + mocked live)

### Engineering (done)
- ✅ Sandbox deterministic fixtures + idempotent API + tenant isolation
- ✅ Webhook signing + delivery logs + retry
- ✅ Audit coverage test, security headers

### You must do ⬜
- ⬜ **Deploy a staging environment** — managed Postgres, object storage bucket
  (for the evidence signed-URL adapter), secrets manager, email provider, error
  tracking. (App is Docker/Fly-ready; `Release.migrate` runs on deploy.)
- ⬜ **Object storage adapter** — implement `FounderPad.Compliance.Storage` against
  S3/GCS and set `:evidence_storage`. (Sandbox adapter ships; this is ~1 file +
  credentials. The behaviour seam is already there.)
- ⬜ **Sign 3 design partners** (LOI + paid/refundable pilot) — see
  `DESIGN_PARTNER_ONBOARDING.md`.
- ⬜ **Privacy notice + DPA template** drafted and legally reviewed.
- ⬜ **Security overview / data-protection posture** one-pager for buyers
  (data minimisation, encryption, audit, retention — all implemented; document it).

### Exit criteria (from VALIDATION_PLAN)
- ⬜ 3 committed design partners within 60 days
- ⬜ ≥1 partner integrates sandbox and runs ≥100 test checks
- ⬜ ≥1 partner with 5,000+ monthly potential checks

## Gate 3 — Live Pilot (real provider, legal sign-off)

### You must procure ⬜ (the critical path)
- ⬜ **Approved NIA / identity verification route** — contract or authorised
    provider/reseller arrangement. *Until this exists, live mode stays disabled (ADR-003).*
- ⬜ **AML provider** with Ghana/Africa coverage (sanctions/PEP/adverse media) + pricing.
- ⬜ **Upstream cost per check confirmed** → validate ≥40% gross margin (kill/continue).
- ⬜ **Data Protection Commission** registration posture confirmed.
- ⬜ **BoG positioning** — assess whether PFTSP/other registration applies to the model.
- ⬜ **Signed DPAs** with customers and with each vendor/subprocessor.
- ⬜ **Privacy/security owner appointed**; incident-response policy approved.
- ⬜ **Independent security review / pen test** before live launch.

### Engineering (small, once contracts exist)
- ⬜ Implement the live `IdentityProvider`/`AmlProvider` adapter(s) against the real
  API and enable behind the existing config flag (the behaviour seam + sandbox + tests
  are already in place — this is a config swap + one module per provider).
- ⬜ **Cloak at-rest encryption** for display PII (names/DOB) — pair with live-provider
  work. (Card/phone/reg#/TIN are already hashed-and-not-stored.)
- ⬜ Backup/restore rehearsal; monitoring/alerting dashboards live.

### Exit criteria
- ⬜ Real provider contract/access + legal/compliance sign-off + signed customer DPA
- ⬜ Live mode passes the same test suite as sandbox, behind the flag
- ⬜ One pilot tenant onboarded end-to-end in live mode

---

## Open questions to close (from PRD)
1. Official/approved route to live Ghana Card verification for this model?
2. Upstream cost per check?
3. Does BoG PFTSP registration apply from day one?
4. Contractual/legal data-retention periods? (windows are configurable in code)
5. Which AML provider has best Ghana/Africa coverage?
6. Fastest-closing segment: lenders, marketplaces, logistics or PSPs?
