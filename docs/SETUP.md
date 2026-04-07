# FounderPad Setup Guide

## Quick Start

1. Clone the repository
2. Install dependencies: `mix deps.get && cd assets && npm install && cd ..`
3. Set up the database: `mix ecto.setup`
4. Seed demo data: `mix run priv/repo/seeds.exs`
5. Start the server: `mix phx.server`
6. Visit http://localhost:4000

**Demo credentials:**
- Admin: admin@founderpad.io / Admin123!
- User: demo@founderpad.io / Demo123!

## Environment Variables

### Required
| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Phoenix session secret (generate with `mix phx.gen.secret`) |
| `PHX_HOST` | Production hostname |

### Email (Required for production)
| Variable | Description |
|----------|-------------|
| `RESEND_API_KEY` | Resend API key for email delivery |

### Payments (Required for billing)
| Variable | Description |
|----------|-------------|
| `STRIPE_SECRET_KEY` | Stripe secret key |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret |

### AI Providers
| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Anthropic Claude API key |
| `OPENAI_API_KEY` | OpenAI API key |

### OAuth (Optional)
| Variable | Description |
|----------|-------------|
| `GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret |
| `GITHUB_CLIENT_ID` | GitHub OAuth client ID |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth client secret |
| `MICROSOFT_CLIENT_ID` | Microsoft OAuth client ID |
| `MICROSOFT_CLIENT_SECRET` | Microsoft OAuth client secret |

### Push Notifications (Optional)
| Variable | Description |
|----------|-------------|
| `VAPID_PUBLIC_KEY` | Web Push VAPID public key |
| `VAPID_PRIVATE_KEY` | Web Push VAPID private key |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Firebase service account JSON for FCM |

### Other
| Variable | Description |
|----------|-------------|
| `PLAUSIBLE_DOMAIN` | Plausible analytics domain |
| `MAINTENANCE_MODE` | Set to "true" to enable maintenance mode |

## Feature Overview

### Authentication
- Email/password + magic links
- OAuth: Google, GitHub, Microsoft (requires provider credentials)
- Two-factor authentication (TOTP)

### Content Management
- Blog CMS at `/admin/blog` with WYSIWYG editor
- Help center at `/admin/help`
- Dynamic changelog at `/admin/changelog`
- SEO dashboard at `/admin/seo`

### Admin Panel
- `/admin` — System dashboard
- `/admin/users` — User management, suspend, impersonate
- `/admin/organisations` — Org management
- `/admin/feature-flags` — Toggle feature flags
- `/admin/incidents` — Status page incident management

### API
- REST API: `/api/v1/*` (JSON:API, auto-generated)
- GraphQL: `/api/graphql`
- API Keys: Generate at `/api-keys`
- Rate limiting: 100 req/min (configurable per plan)

### Billing
- Stripe integration with 4 plans (Free, Starter, Pro, Enterprise)
- Usage tracking at `/usage`
- Plan limits enforced per API key

### Notifications
- In-app real-time (Phoenix PubSub)
- Email (Swoosh + Resend)
- Push notifications (FCM + Web Push)
- Onboarding drip emails

### GDPR Compliance
- Cookie consent banner
- Data export (JSON download)
- Account deletion (30-day grace period)
- One-click email unsubscribe
- Privacy policy at `/privacy`

## Deployment

### Fly.io
```bash
fly launch
fly secrets set DATABASE_URL=... SECRET_KEY_BASE=... RESEND_API_KEY=...
fly deploy
```

### Docker
```bash
docker-compose up -d
```

## Making It Yours

1. Update branding in `config/branding.exs`
2. Customize the landing page at `lib/founder_pad_web/live/landing_live.ex`
3. Update privacy policy at `lib/founder_pad_web/live/privacy_live.ex`
4. Add your Stripe plans in `config/plans.exs`
5. Customize email templates in `lib/founder_pad/notifications/mailers/`
