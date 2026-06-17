# GhanaTrust API — Sandbox Quickstart

Run your first identity verification in sandbox in a few minutes. Sandbox is
deterministic and contacts no external service, so you can build and test safely.

## 1. Get a sandbox API key

Locally, seed a demo tenant and key (the raw key is printed once):

```bash
mix run priv/repo/ghanatrust_seeds.exs
# →  🔑 Sandbox API key (save this — shown once): fp_xxxxxxxx...
```

Or, in the dashboard: **API Keys → New API Key** with the `read` and `write` scopes
(test mode). Copy the raw key — it is shown only once.

```bash
export GT_KEY=fp_xxxxxxxx...
export GT_URL=http://localhost:4000
```

## 2. Create a verification

Use a sandbox fixture so the outcome is predictable. `GHA-TEST-VERIFIED-1` always
verifies.

```bash
curl -sS -X POST "$GT_URL/v1/individual_verifications" \
  -H "Authorization: Bearer $GT_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{
        "external_id": "customer_001",
        "person": {
          "ghana_card_number": "GHA-TEST-VERIFIED-1",
          "first_name": "Ama",
          "last_name": "Mensah",
          "date_of_birth": "1995-04-12",
          "phone_number": "+233241234567"
        }
      }'
```

```json
{ "id": "…", "status": "verified", "mode": "test",
  "external_id": "customer_001", "created_at": "…",
  "links": { "self": "/v1/individual_verifications/…" } }
```

Try the other fixtures: `GHA-TEST-REVIEW-1` → `requires_review` (opens a review case),
`GHA-TEST-FAILED-1` → `failed`, `GHA-TEST-PROVIDER-DOWN` → provider outage.

## 3. Retrieve it

```bash
curl -sS "$GT_URL/v1/individual_verifications/<id>" \
  -H "Authorization: Bearer $GT_KEY"
```

Returns `status`, `identity` (verified/match_level), `risk` (level/score/reason_codes)
and consent reference.

## 4. Receive webhooks (optional)

Subscribe an endpoint (in the dashboard: **Webhooks**) to
`individual_verification.completed` and `individual_verification.requires_review`.
Deliveries are **signed** and retried with backoff; you can inspect them under Webhooks.

Each delivery carries these headers:

| Header | Meaning |
|---|---|
| `x-webhook-signature` | hex HMAC-SHA256 of `"<x-webhook-timestamp>.<raw_body>"` keyed by your endpoint secret |
| `x-webhook-timestamp` | unix seconds (reject if too old, to prevent replay) |
| `x-webhook-event` | e.g. `individual_verification.completed` |

Verify (pseudocode): `hmac_sha256(secret, timestamp + "." + raw_body) == x-webhook-signature`.

## 5. Go to live mode

Live keys (`mode: live`) require a **consent receipt** on every verification — pass a
`consent` block in the request. Live identity processing is disabled until an approved
NIA/partner provider route is configured; sandbox is the supported path until then.

## Notes

- **Idempotency:** send `Idempotency-Key` on writes; a retry with the same key + body
  replays the original response. A different body with the same key returns
  `409 duplicate_idempotency_key`.
- **Scopes:** creating needs `write`; retrieving needs `read` (`admin` implies both).
- **Errors:** `{ "error": { "code", "message", "request_id" } }` — quote `request_id`
  in support requests.
- **Full contract:** `GET /v1/openapi.json` (OpenAPI 3) and `docs/GHANATRUST.md`.
