# GhanaTrust — Design Partner Outreach & Onboarding Kit

Operationalizes Phase 0 validation: find 5×4 operators, run problem interviews, make the
design-partner offer, and onboard them into the **sandbox that's live today**. Grounded in
`GO_TO_MARKET.md` and `VALIDATION_PLAN.md`.

Goal (kill/continue): **3 committed design partners within 60 days**, ≥1 with 5,000+
monthly potential checks.

---

## 1. Target list (20 operators)

| Segment | Count | Why |
|---|---|---|
| Digital lenders | 5 | High onboarding volume; identity risk = direct loss |
| Fintech / PSP teams | 5 | Have dev teams; understand API value |
| Marketplaces / logistics | 5 | Rider/merchant onboarding at scale |
| Compliance consultants / officers | 3 | Channel + objection insight |
| Rural bank / savings & loans | 2 | Secondary, warm access only |

Channels: founder direct outreach, Ghana fintech communities, LinkedIn to CTOs/compliance
leads, compliance-consultant and dev-agency partnerships.

## 2. Cold outreach email (template)

> **Subject:** Ghana-ready KYC/KYB in your stack — 20 min?
>
> Hi {First name},
>
> I'm building **GhanaTrust** — a Ghana-first API for KYC, KYB, AML screening, consent
> receipts and audit evidence, so teams like {Company} don't build verification and
> compliance plumbing from scratch.
>
> I'm not selling yet — I'm choosing a few **design partners** to shape it. You'd get a
> discounted 6-month pilot, hands-on integration support, and direct influence on the
> roadmap. There's a **sandbox you can integrate against today** (deterministic test
> data, no contracts needed).
>
> Could I get 20 minutes to learn how {Company} verifies customers today and where it
> breaks? No pitch — just questions.
>
> — {Your name}

Follow-up (after 3 days): one line — *"Bumping this — even a quick no is useful. Happy to
send the 1-page security/data-protection overview first if that's easier."*

## 3. Problem interview script (20 min, no pitching)

From `VALIDATION_PLAN.md` — listen, don't sell:

1. How do you verify customers today?
2. Which checks are mandatory for your workflow?
3. What causes onboarding delays?
4. What fraud patterns are you seeing?
5. What records do you keep for compliance? What happens during audits/partner reviews?
6. How many customers/merchants/agents do you onboard monthly?
7. What's your current cost per verification?
8. What would make you switch?
9. Would you pay for a pilot — and how much?

**Capture per interview:** segment, monthly volume, current cost/check, mandatory checks,
top pain, budget owner, would-pay (Y/N + amount).

## 4. Read the signal (don't fool yourself)

| Strong (pursue) | Weak (park) |
|---|---|
| Paid pilot / signed LOI | "This is interesting" |
| Technical integration call booked | Free-trial interest only |
| Shares current workflow / screenshots | No clear owner |
| Asks for pricing, SLA, security review | No verification volume |

## 5. The design-partner offer

**Give:** discounted 6-month pilot (GHS 1,500–3,000/mo), implementation support,
roadmap influence, founder-level support.
**Ask:** signed LOI, paid pilot or refundable deposit, integration feedback, case study
if it works.

## 6. Sandbox onboarding (once they say yes)

The product is ready for this **now** — no provider contract needed for sandbox.

1. Create their tenant + a **sandbox API key** (`test` mode) in the dashboard.
2. Send `docs/QUICKSTART.md` — they create a verification with `GHA-TEST-VERIFIED-1`,
   retrieve it, and subscribe a webhook in minutes.
3. Walk them through the dashboard: verifications, consent, KYB, AML, review queue.
4. Point them at `GET /v1/openapi.json` for client generation.
5. Have them run the fixtures (`GHA-TEST-REVIEW-1`, `CS-TEST-*`, `AML-PEP`) to see the
   review/risk/webhook flow end to end.

**Pilot success (from VALIDATION_PLAN):** integrates sandbox, runs ≥100 test checks,
confirms compliance-workflow fit, agrees to a paid live pilot pending provider access,
and names 1–2 must-have features.

## 7. Handling the inevitable objections

- *"We already have verification."* → GhanaTrust adds consent receipts, audit evidence,
  manual review, webhooks, KYB and AML *around* verification — the compliance layer.
- *"What about data security?"* → data minimisation (PII hashed, not stored raw),
  redacted logs, audit trail, configurable retention, tenant isolation, customer DPA.
  Send the security overview.
- *"We need official Ghana Card verification."* → live verification needs approved
  provider access; you start in sandbox + integration layer today, live mode flips on
  once that access is in place. The integration work is done either way.
- *"Pricing is high."* → compare to fraud loss + manual-review cost + failed onboarding
  + audit exposure.

## 8. What to build next *only if* interviews demand it

Don't pre-build. If partners repeatedly ask for it: the mobile PWA field-capture flow
(backend ready), or specific provider adapters. Let the 1–2 named must-haves drive it.
