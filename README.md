# FounderPad

**Ship your SaaS faster with AI-powered agent orchestration.**

FounderPad is a production-ready SaaS boilerplate built with Elixir, Phoenix LiveView, and the Ash Framework. It provides multi-tenant workspaces, AI agent management (Anthropic + OpenAI), Stripe billing, team collaboration, and a real-time dashboard — all wired together and ready to deploy.

---

## Features

- **AI Agent Orchestration** — Deploy and manage AI agents across Anthropic and OpenAI with real-time chat, configurable parameters, and usage tracking
- **Multi-Tenant Workspaces** — Organisation-scoped data isolation with role-based memberships (owner, admin, member)
- **Stripe Billing** — Plans, checkout, usage metering, and webhook handling built in
- **Real-Time Dashboard** — Live metrics, auto-refreshing stats, and fleet performance monitoring
- **Team Management** — Invite members, manage roles, and track team activity
- **Auth System** — Registration, login, magic links, password reset, and session management via AshAuthentication
- **Activity Feed** — Real-time audit logging with multi-source event streaming
- **Notification System** — In-app notifications with PubSub broadcasting and email delivery (Swoosh)
- **Settings** — Profile editing, theme switching (dark/light), compact UI, high contrast, 2FA toggle
- **Documentation Pages** — Built-in docs, API reference, and changelog
- **Landing Page** — SEO-optimized marketing page with pricing, testimonials, and feature showcase

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Elixir 1.17+ |
| Framework | Phoenix 1.7+ / LiveView 1.1+ |
| Domain Layer | Ash Framework 3.x |
| Database | PostgreSQL 15+ |
| Background Jobs | Oban |
| Payments | Stripe (via stripe-elixir) |
| Email | Swoosh |
| AI Providers | Anthropic API, OpenAI API |
| APIs | JSON:API (AshJsonApi) + GraphQL (AshGraphql) |
| Auth | AshAuthentication + AshAuthentication.Phoenix |
| CSS | TailwindCSS 4.x |
| JS | Phoenix LiveView hooks + Stimulus-style |

## Quick Start

```bash
# 1. Clone and install
git clone <repo-url> founderpad && cd founderpad
mix setup

# 2. Configure environment
cp .env.example .env  # Add your Stripe + AI API keys

# 3. Start the server
mix phx.server
```

Visit [localhost:4001](http://localhost:4001) to see the landing page. Register an account, complete onboarding, and deploy your first AI agent.

## Architecture

```
lib/founder_pad/              # Domain layer (Ash resources)
├── accounts/                 #   Users, Organisations, Memberships
├── ai/                       #   Agents, Conversations, Messages, AgentRunner
├── billing/                  #   Plans, Subscriptions, UsageRecords
├── notifications/            #   Notifications, EmailLogs, Mailers
├── audit/                    #   AuditLog
├── analytics/                #   AppEvents
├── feature_flags/            #   Feature flags
├── tooling/                  #   AI tool definitions
└── webhooks/                 #   Stripe webhook processing

lib/founder_pad_web/          # Web layer
├── live/                     #   15 LiveView screens
├── components/               #   Reusable UI components
├── hooks/                    #   LiveView on_mount hooks
├── controllers/              #   Auth, checkout, webhooks
└── api/                      #   JSON:API + GraphQL routers
```

## API Access

FounderPad auto-generates REST and GraphQL APIs from Ash resources:

- **REST (JSON:API):** `GET /api/v1/agents`, `GET /api/v1/agents/:id`
- **GraphQL:** `POST /api/graphql` (schema introspection at `/api/graphiql` in dev)

## Development

```bash
mix test                      # Run test suite (~196 tests)
mix founder_pad.reset         # Reset database
mix founder_pad.seed          # Seed demo data
mix founder_pad.seed_plans    # Seed billing plans
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Phoenix secret key |
| `STRIPE_SECRET_KEY` | Stripe API key |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret |
| `ANTHROPIC_API_KEY` | Anthropic (Claude) API key |
| `OPENAI_API_KEY` | OpenAI API key |

## License

Private. All rights reserved.
