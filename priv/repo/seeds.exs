# priv/repo/seeds.exs
# Run with: mix run priv/repo/seeds.exs

alias FounderPad.{Accounts, Content, HelpCenter, FeatureFlags, AI}

IO.puts("🌱 Seeding FounderPad...")

# --- Admin User ---
IO.puts("  Creating admin user...")

{:ok, admin} =
  FounderPad.Repo.insert(%Accounts.User{
    id: Ecto.UUID.generate(),
    email: %Ash.CiString{string: "admin@founderpad.io"},
    hashed_password: Bcrypt.hash_pwd_salt("Admin123!"),
    name: "Admin User",
    is_admin: true,
    preferences: %{},
    email_preferences: %{
      "marketing" => true,
      "product_updates" => true,
      "weekly_digest" => true,
      "billing" => true,
      "team" => true
    }
  })

IO.puts("    Admin: admin@founderpad.io / Admin123!")

# --- Demo User ---
IO.puts("  Creating demo user...")

{:ok, demo_user} =
  FounderPad.Repo.insert(%Accounts.User{
    id: Ecto.UUID.generate(),
    email: %Ash.CiString{string: "demo@founderpad.io"},
    hashed_password: Bcrypt.hash_pwd_salt("Demo123!"),
    name: "Demo User",
    is_admin: false,
    preferences: %{},
    email_preferences: %{
      "marketing" => true,
      "product_updates" => true,
      "weekly_digest" => true,
      "billing" => true,
      "team" => true
    }
  })

IO.puts("    Demo: demo@founderpad.io / Demo123!")

# --- Organisation ---
IO.puts("  Creating organisation...")

{:ok, org} =
  Accounts.Organisation
  |> Ash.Changeset.for_create(:create, %{name: "Acme Corp"})
  |> Ash.create()

Accounts.Membership
|> Ash.Changeset.for_create(:create, %{user_id: admin.id, organisation_id: org.id, role: :owner})
|> Ash.create!(authorize?: false)

Accounts.Membership
|> Ash.Changeset.for_create(:create, %{
  user_id: demo_user.id,
  organisation_id: org.id,
  role: :member
})
|> Ash.create!(authorize?: false)

# --- Feature Flags ---
IO.puts("  Creating feature flags...")

flags = [
  %{
    key: "dark_mode",
    name: "Dark Mode",
    description: "Enable dark theme across the app",
    enabled: true
  },
  %{
    key: "api_webhooks",
    name: "API Webhooks",
    description: "Allow outbound webhook configuration",
    enabled: true,
    required_plan: "starter"
  },
  %{
    key: "ai_agents",
    name: "AI Agents",
    description: "Access to AI agent creation and management",
    enabled: true
  },
  %{
    key: "team_collaboration",
    name: "Team Collaboration",
    description: "Multi-user team features",
    enabled: true,
    required_plan: "starter"
  },
  %{
    key: "advanced_analytics",
    name: "Advanced Analytics",
    description: "Detailed usage analytics and reports",
    enabled: false,
    required_plan: "pro"
  },
  %{
    key: "custom_branding",
    name: "Custom Branding",
    description: "White-label branding options",
    enabled: false,
    required_plan: "enterprise"
  },
  %{
    key: "maintenance_mode",
    name: "Maintenance Mode",
    description: "Enable maintenance mode for the entire app",
    enabled: false
  },
  %{
    key: "beta_features",
    name: "Beta Features",
    description: "Early access to upcoming features",
    enabled: false
  }
]

for flag <- flags do
  FeatureFlags.FeatureFlag
  |> Ash.Changeset.for_create(:create, flag, actor: admin)
  |> Ash.create!(authorize?: false)
end

# --- Blog Categories ---
IO.puts("  Creating blog categories...")

categories = [
  %{
    name: "Product Updates",
    description: "New features and improvements",
    slug: "product-updates"
  },
  %{
    name: "Engineering",
    description: "Technical deep dives and architecture",
    slug: "engineering"
  },
  %{name: "Tutorials", description: "Step-by-step guides", slug: "tutorials"},
  %{name: "Company", description: "Team news and announcements", slug: "company"},
  %{
    name: "Documentation",
    description: "Setup guides and feature reference",
    slug: "documentation"
  }
]

blog_cats =
  for cat <- categories do
    Content.Category
    |> Ash.Changeset.for_create(:create, cat, actor: admin)
    |> Ash.create!(authorize?: false)
  end

# --- Blog Posts ---
IO.puts("  Creating blog posts...")

posts = [
  %{
    title: "Introducing FounderPad: Ship SaaS in Days, Not Months",
    body:
      "<p>We're excited to launch FounderPad, the most complete SaaS boilerplate for Elixir and Phoenix.</p><p>With built-in authentication, billing, AI agent management, team collaboration, and more — you can focus on what makes your product unique instead of rebuilding the same infrastructure every startup needs.</p><h2>What's Included</h2><ul><li>Multi-tenant workspaces with RBAC</li><li>Stripe billing with 4-tier plans</li><li>AI agent orchestration (Anthropic + OpenAI)</li><li>Real-time notifications</li><li>Admin panel with impersonation</li></ul><p>Get started at <a href='/'>founderpad.io</a>.</p>",
    excerpt:
      "The most complete SaaS boilerplate for Elixir and Phoenix. Ship in days, not months.",
    status: :published,
    published_at: DateTime.utc_now(),
    category_id: Enum.at(blog_cats, 0).id
  },
  %{
    title: "Building AI Agents with FounderPad",
    body:
      "<p>Learn how to create, configure, and deploy AI agents using FounderPad's built-in agent management system.</p><h2>Creating Your First Agent</h2><p>Navigate to the Agents page and click 'New Agent'. Configure the system prompt, choose your provider (Anthropic or OpenAI), and set the model parameters.</p><h2>Best Practices</h2><ol><li>Write clear, specific system prompts</li><li>Set appropriate temperature (0.1-0.3 for factual, 0.7-0.9 for creative)</li><li>Use tool definitions for structured outputs</li><li>Monitor token usage in the analytics dashboard</li></ol>",
    excerpt: "Step-by-step guide to creating and deploying AI agents with FounderPad.",
    status: :published,
    published_at: DateTime.add(DateTime.utc_now(), -3 * 86400, :second),
    category_id: Enum.at(blog_cats, 2).id
  },
  %{
    title: "How We Built Real-Time Collaboration with Phoenix Presence",
    body:
      "<p>A deep dive into how FounderPad uses Phoenix Presence to enable real-time collaboration on agent configurations.</p><p>Phoenix Presence leverages CRDTs (Conflict-free Replicated Data Types) to track which users are online and what they're working on — all without a single database query.</p>",
    excerpt: "Technical deep dive into Phoenix Presence for real-time collaboration.",
    status: :draft,
    category_id: Enum.at(blog_cats, 1).id
  }
]

for post <- posts do
  post_params = post |> Map.drop([:category_id]) |> Map.put(:author_id, admin.id)

  p =
    Content.Post
    |> Ash.Changeset.for_create(:create, post_params, actor: admin)
    |> Ash.create!(authorize?: false)

  if post.status == :published do
    p |> Ash.Changeset.for_update(:publish, %{}, actor: admin) |> Ash.update!(authorize?: false)
  end
end

# --- Documentation Posts (dog-fooding the blog CMS as docs) ---
IO.puts("  Creating documentation posts...")
docs_cat = Enum.at(blog_cats, 4)
tutorials_cat = Enum.at(blog_cats, 2)

doc_posts = [
  %{
    title: "Quick Start: From Clone to Running App in 5 Minutes",
    body: """
    <h2>Prerequisites</h2>
    <ul><li>Elixir 1.17+ and Erlang/OTP 27+</li><li>PostgreSQL 15+</li><li>Node.js 20+ (for assets)</li></ul>
    <h2>Setup</h2>
    <pre><code>git clone &lt;your-repo&gt; my_app
    cd my_app
    mix founder_pad.setup
    mix phx.server</code></pre>
    <p>Visit <code>http://localhost:4000</code>. Log in with <strong>admin@founderpad.io / Admin123!</strong></p>
    <h2>Renaming the App</h2>
    <p>Run <code>mix founder_pad.rename MyApp my_app</code> to rebrand the entire codebase to your app name. This updates all modules, configs, and file paths.</p>
    <h2>Next Steps</h2>
    <ol><li>Update <code>config/branding.exs</code> with your brand name, colors, and logo</li><li>Configure Stripe keys in <code>config/runtime.exs</code></li><li>Set up OAuth providers (Google, GitHub) in your environment</li><li>Deploy to Fly.io with <code>fly launch</code></li></ol>
    """,
    excerpt: "Get FounderPad running locally in under 5 minutes with this quick start guide.",
    status: :published,
    published_at: DateTime.utc_now(),
    category_id: docs_cat.id
  },
  %{
    title: "Architecture Guide: How FounderPad is Organized",
    body: """
    <h2>Domain-Driven Design with Ash</h2>
    <p>FounderPad uses the Ash Framework to implement clean domain boundaries. Each domain is a self-contained module with its own resources, actions, and policies.</p>
    <h2>The 13 Domains</h2>
    <ul>
    <li><strong>Accounts</strong> — Users, organisations, memberships, OAuth identities</li>
    <li><strong>AI</strong> — Agents, conversations, messages, tool calls, templates</li>
    <li><strong>Billing</strong> — Stripe plans, subscriptions, invoices, usage tracking</li>
    <li><strong>Content</strong> — Blog posts, categories, tags, changelog, SEO</li>
    <li><strong>Analytics</strong> — App events, Google Search Console data</li>
    <li><strong>Notifications</strong> — Email, push (FCM/Web Push), in-app via PubSub</li>
    <li><strong>Privacy</strong> — GDPR cookie consent, data export, account deletion</li>
    <li><strong>Webhooks</strong> — Outbound webhooks with delivery tracking and retries</li>
    <li><strong>Audit</strong> — Immutable append-only audit logs</li>
    <li><strong>ApiKeys</strong> — SHA-256 hashed API keys with usage metering</li>
    <li><strong>FeatureFlags</strong> — Global toggles with per-plan gating</li>
    <li><strong>HelpCenter</strong> — FAQ CMS with PostgreSQL full-text search</li>
    <li><strong>System</strong> — Status page incidents</li>
    </ul>
    <h2>Web Layer</h2>
    <p>Phoenix LiveView handles all interactive pages. Controllers are used only for non-LiveView endpoints (RSS feeds, OAuth callbacks, API endpoints). Plugs handle cross-cutting concerns like rate limiting, API auth, and maintenance mode.</p>
    """,
    excerpt: "Understand the domain-driven architecture behind FounderPad's 13 bounded contexts.",
    status: :published,
    published_at: DateTime.add(DateTime.utc_now(), -86_400, :second),
    category_id: docs_cat.id
  },
  %{
    title: "Customizing Billing Plans and Stripe Integration",
    body: """
    <h2>Plan Configuration</h2>
    <p>Plans are defined in <code>config/plans.exs</code>. Each plan specifies limits for seats, agents, and monthly API calls:</p>
    <pre><code>config :founder_pad, :plans, [
      %{name: "Free", price_monthly: 0, max_seats: 1, max_agents: 1, max_api_calls: 1_000},
      %{name: "Starter", price_monthly: 2900, max_seats: 5, max_agents: 10, max_api_calls: 50_000},
      %{name: "Pro", price_monthly: 7900, max_seats: 20, max_agents: 50, max_api_calls: 500_000},
      %{name: "Enterprise", price_monthly: 19900, max_seats: -1, max_agents: -1, max_api_calls: -1}
    ]</code></pre>
    <h2>Stripe Setup</h2>
    <ol><li>Create products and prices in your Stripe Dashboard</li><li>Set <code>STRIPE_SECRET_KEY</code> and <code>STRIPE_WEBHOOK_SECRET</code> in your environment</li><li>The checkout flow handles subscription creation, plan changes, and cancellation automatically</li></ol>
    <h2>Usage Metering</h2>
    <p>API calls are tracked per-organisation via the <code>ApiKeys.ApiKeyUsage</code> resource. Usage is checked against plan limits on every API request through the <code>ApiKeyAuth</code> plug.</p>
    """,
    excerpt: "Configure Stripe plans, pricing tiers, and usage metering for your SaaS.",
    status: :published,
    published_at: DateTime.add(DateTime.utc_now(), -2 * 86_400, :second),
    category_id: tutorials_cat.id
  },
  %{
    title: "Adding OAuth Providers: Google, GitHub, and Microsoft",
    body: """
    <h2>Overview</h2>
    <p>FounderPad supports OAuth login via Google, GitHub, and Microsoft. Social identities are linked to existing accounts, allowing users to sign in with multiple methods.</p>
    <h2>Configuration</h2>
    <p>Set these environment variables for each provider you want to enable:</p>
    <pre><code># Google
    GOOGLE_CLIENT_ID=your_client_id
    GOOGLE_CLIENT_SECRET=your_client_secret

    # GitHub
    GITHUB_CLIENT_ID=your_client_id
    GITHUB_CLIENT_SECRET=your_client_secret

    # Microsoft
    MICROSOFT_CLIENT_ID=your_client_id
    MICROSOFT_CLIENT_SECRET=your_client_secret</code></pre>
    <h2>How It Works</h2>
    <ol><li>User clicks "Sign in with Google" on the login page</li><li>OAuth callback creates or links a <code>SocialIdentity</code> record</li><li>If the email matches an existing account, identities are linked</li><li>Users can manage connected accounts in Settings</li></ol>
    """,
    excerpt: "Set up Google, GitHub, and Microsoft OAuth login for your users.",
    status: :published,
    published_at: DateTime.add(DateTime.utc_now(), -3 * 86_400, :second),
    category_id: tutorials_cat.id
  },
  %{
    title: "GDPR Compliance: Privacy Tools Built In",
    body: """
    <h2>What's Included</h2>
    <p>FounderPad ships with GDPR compliance tools out of the box:</p>
    <h3>Cookie Consent</h3>
    <p>A cookie consent banner tracks user consent with IP address and user-agent. Managed via the <code>Privacy.CookieConsent</code> resource.</p>
    <h3>Data Export (Right to Portability)</h3>
    <p>Users can request a full data export from Settings. An Oban worker compiles their data into a JSON file available for 48 hours.</p>
    <h3>Account Deletion (Right to Erasure)</h3>
    <p>Account deletion follows a safe pipeline: request → confirmation email → 30-day grace period → soft delete → hard delete. Users can cancel during the grace period.</p>
    <h3>Email Preferences</h3>
    <p>One-click unsubscribe via signed tokens. Users control 5 email categories: marketing, product updates, weekly digest, billing, and team notifications.</p>
    """,
    excerpt:
      "Cookie consent, data export, account deletion, and email preferences — all built in.",
    status: :published,
    published_at: DateTime.add(DateTime.utc_now(), -4 * 86_400, :second),
    category_id: docs_cat.id
  }
]

for doc_post <- doc_posts do
  post_params = doc_post |> Map.drop([:category_id]) |> Map.put(:author_id, admin.id)

  p =
    Content.Post
    |> Ash.Changeset.for_create(:create, post_params, actor: admin)
    |> Ash.create!(authorize?: false)

  if doc_post.status == :published do
    p |> Ash.Changeset.for_update(:publish, %{}, actor: admin) |> Ash.update!(authorize?: false)
  end
end

# --- Changelog Entries ---
IO.puts("  Creating changelog entries...")

changelog = [
  %{
    version: "v2.0.0",
    title: "Production Features Release",
    body:
      "<ul><li>Blog CMS with WYSIWYG editor</li><li>SEO engine with JSON-LD structured data</li><li>Admin panel with user management</li><li>API key management</li><li>Help center with full-text search</li><li>Push notifications (FCM + Web Push)</li><li>OAuth social login</li><li>GDPR compliance tools</li></ul>",
    type: :feature
  },
  %{
    version: "v1.1.0",
    title: "Production Polish",
    body:
      "<ul><li>Working agent chat with PubSub streaming</li><li>Stripe checkout with graceful degradation</li><li>Notification system with email delivery</li></ul>",
    type: :improvement
  },
  %{
    version: "v1.0.0",
    title: "Initial Release",
    body:
      "<ul><li>Authentication (email/password + magic links)</li><li>Multi-tenant workspaces</li><li>AI agent CRUD</li><li>Stripe billing integration</li></ul>",
    type: :feature
  }
]

for entry <- changelog do
  e =
    Content.ChangelogEntry
    |> Ash.Changeset.for_create(:create, Map.put(entry, :author_id, admin.id), actor: admin)
    |> Ash.create!(authorize?: false)

  e |> Ash.Changeset.for_update(:publish, %{}, actor: admin) |> Ash.update!(authorize?: false)
end

# --- Help Center ---
IO.puts("  Creating help center content...")

help_categories = [
  %{
    name: "Getting Started",
    slug: "getting-started",
    description: "New to FounderPad? Start here.",
    icon: "rocket_launch",
    position: 0
  },
  %{
    name: "Billing & Plans",
    slug: "billing",
    description: "Manage your subscription and payments.",
    icon: "credit_card",
    position: 1
  },
  %{
    name: "AI Agents",
    slug: "agents",
    description: "Create and configure AI agents.",
    icon: "smart_toy",
    position: 2
  },
  %{
    name: "API & Integrations",
    slug: "api",
    description: "Connect to FounderPad programmatically.",
    icon: "code",
    position: 3
  },
  %{
    name: "Team & Workspaces",
    slug: "team",
    description: "Collaborate with your team.",
    icon: "group",
    position: 4
  },
  %{
    name: "Security",
    slug: "security",
    description: "Keep your account secure.",
    icon: "shield",
    position: 5
  }
]

help_cats =
  for cat <- help_categories do
    HelpCenter.Category
    |> Ash.Changeset.for_create(:create, cat, actor: admin)
    |> Ash.create!(authorize?: false)
  end

help_articles = [
  %{
    title: "Creating Your Account",
    slug: "creating-account",
    body:
      "Sign up at /auth/register with your email and a password. You'll receive a welcome email with tips to get started.",
    excerpt: "How to sign up for FounderPad",
    category_id: Enum.at(help_cats, 0).id,
    position: 0,
    help_context_key: "auth.register"
  },
  %{
    title: "Setting Up Your First Workspace",
    slug: "first-workspace",
    body:
      "After registration, the onboarding wizard guides you through creating your first organisation. Give it a name, invite team members, and choose a plan.",
    excerpt: "Create your organisation and invite your team",
    category_id: Enum.at(help_cats, 0).id,
    position: 1,
    help_context_key: "onboarding"
  },
  %{
    title: "Understanding Plans & Pricing",
    slug: "plans-pricing",
    body:
      "FounderPad offers 4 tiers: Free (1 agent, 1K API calls), Starter ($29/mo, 10 agents), Pro ($79/mo, 50 agents), Enterprise ($199/mo, unlimited). Upgrade anytime from the Billing page.",
    excerpt: "Compare plans and pricing",
    category_id: Enum.at(help_cats, 1).id,
    position: 0,
    help_context_key: "billing.plans"
  },
  %{
    title: "Managing API Keys",
    slug: "api-keys",
    body:
      "Generate API keys from the API Keys page. Each key has scoped permissions (read, write, admin). Keys are shown once on creation — save them securely. Revoke compromised keys immediately.",
    excerpt: "Create, manage, and revoke API keys",
    category_id: Enum.at(help_cats, 3).id,
    position: 0,
    help_context_key: "api-keys"
  },
  %{
    title: "Enabling Two-Factor Authentication",
    slug: "two-factor-auth",
    body:
      "Go to Settings → Two-Factor Authentication. Scan the QR code with your authenticator app (Google Authenticator, Authy). Enter the 6-digit code to verify. Save your backup codes in a secure location.",
    excerpt: "Secure your account with 2FA",
    category_id: Enum.at(help_cats, 5).id,
    position: 0,
    help_context_key: "settings.two-factor"
  }
]

for article <- help_articles do
  a =
    HelpCenter.Article
    |> Ash.Changeset.for_create(:create, article, actor: admin)
    |> Ash.create!(authorize?: false)

  a |> Ash.Changeset.for_update(:publish, %{}, actor: admin) |> Ash.update!(authorize?: false)
end

# --- Agent Templates ---
IO.puts("  Creating agent templates...")

templates = [
  %{
    name: "Customer Support Bot",
    description: "Handles common customer inquiries, FAQ lookups, and ticket routing.",
    category: "Support",
    system_prompt:
      "You are a helpful customer support agent for a SaaS product. Answer questions clearly and concisely. If you can't help, offer to escalate to a human agent.",
    icon: "support_agent",
    featured: true
  },
  %{
    name: "Code Review Assistant",
    description: "Reviews code for bugs, style issues, and suggests improvements.",
    category: "Engineering",
    system_prompt:
      "You are an expert code reviewer. Analyze the provided code for bugs, security issues, performance problems, and style inconsistencies. Provide specific, actionable feedback with code examples.",
    icon: "code",
    featured: true
  },
  %{
    name: "Content Writer",
    description: "Generates blog posts, social media content, and marketing copy.",
    category: "Marketing",
    system_prompt:
      "You are a skilled content writer. Create engaging, well-structured content that is SEO-friendly and matches the brand voice. Include relevant keywords naturally.",
    icon: "edit_note",
    featured: true
  },
  %{
    name: "Data Analyst",
    description: "Analyzes data, creates summaries, and identifies trends.",
    category: "Analytics",
    system_prompt:
      "You are a data analyst. Analyze the provided data, identify patterns and trends, and present findings in a clear, actionable format with specific recommendations.",
    icon: "analytics",
    featured: false
  },
  %{
    name: "Meeting Summarizer",
    description: "Summarizes meeting transcripts into action items and key decisions.",
    category: "Productivity",
    system_prompt:
      "You are a meeting summarizer. Extract key decisions, action items with owners, and important discussion points from meeting transcripts. Format as a structured summary.",
    icon: "summarize",
    featured: false
  }
]

for tmpl <- templates do
  AI.AgentTemplate
  |> Ash.Changeset.for_create(:create, tmpl, actor: admin)
  |> Ash.create!(authorize?: false)
end

IO.puts("✅ Seed complete!")
IO.puts("")
IO.puts("  Admin login:  admin@founderpad.io / Admin123!")
IO.puts("  Demo login:   demo@founderpad.io / Demo123!")
IO.puts("  Organisation: Acme Corp")
