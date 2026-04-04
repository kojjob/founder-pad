# priv/repo/seeds.exs
# Run with: mix run priv/repo/seeds.exs

alias FounderPad.{Accounts, Content, HelpCenter, FeatureFlags, AI}

IO.puts("🌱 Seeding FounderPad...")

# --- Admin User ---
IO.puts("  Creating admin user...")
{:ok, admin} =
  Accounts.User
  |> Ash.Changeset.for_create(:register_with_password, %{
    email: "admin@founderpad.io",
    password: "Admin123!",
    password_confirmation: "Admin123!"
  })
  |> Ash.create()

admin
|> Ash.Changeset.for_update(:update_profile, %{name: "Admin User"})
|> Ash.update!()

admin
|> Ash.Changeset.force_change_attribute(:is_admin, true)
|> Ash.update!()

# --- Demo User ---
IO.puts("  Creating demo user...")
{:ok, demo_user} =
  Accounts.User
  |> Ash.Changeset.for_create(:register_with_password, %{
    email: "demo@founderpad.io",
    password: "Demo123!",
    password_confirmation: "Demo123!"
  })
  |> Ash.create()

demo_user
|> Ash.Changeset.for_update(:update_profile, %{name: "Demo User"})
|> Ash.update!()

# --- Organisation ---
IO.puts("  Creating organisation...")
{:ok, org} =
  Accounts.Organisation
  |> Ash.Changeset.for_create(:create, %{name: "Acme Corp"})
  |> Ash.create()

Accounts.Membership
|> Ash.Changeset.for_create(:create, %{user_id: admin.id, organisation_id: org.id, role: :owner})
|> Ash.create!()

Accounts.Membership
|> Ash.Changeset.for_create(:create, %{user_id: demo_user.id, organisation_id: org.id, role: :member})
|> Ash.create!()

# --- Feature Flags ---
IO.puts("  Creating feature flags...")
flags = [
  %{key: "dark_mode", name: "Dark Mode", description: "Enable dark theme across the app", enabled: true},
  %{key: "api_webhooks", name: "API Webhooks", description: "Allow outbound webhook configuration", enabled: true, required_plan: "starter"},
  %{key: "ai_agents", name: "AI Agents", description: "Access to AI agent creation and management", enabled: true},
  %{key: "team_collaboration", name: "Team Collaboration", description: "Multi-user team features", enabled: true, required_plan: "starter"},
  %{key: "advanced_analytics", name: "Advanced Analytics", description: "Detailed usage analytics and reports", enabled: false, required_plan: "pro"},
  %{key: "custom_branding", name: "Custom Branding", description: "White-label branding options", enabled: false, required_plan: "enterprise"},
  %{key: "maintenance_mode", name: "Maintenance Mode", description: "Enable maintenance mode for the entire app", enabled: false},
  %{key: "beta_features", name: "Beta Features", description: "Early access to upcoming features", enabled: false}
]

for flag <- flags do
  FeatureFlags.FeatureFlag
  |> Ash.Changeset.for_create(:create, flag, actor: admin)
  |> Ash.create!()
end

# --- Blog Categories ---
IO.puts("  Creating blog categories...")
categories = [
  %{name: "Product Updates", description: "New features and improvements", slug: "product-updates"},
  %{name: "Engineering", description: "Technical deep dives and architecture", slug: "engineering"},
  %{name: "Tutorials", description: "Step-by-step guides", slug: "tutorials"},
  %{name: "Company", description: "Team news and announcements", slug: "company"}
]

blog_cats = for cat <- categories do
  Content.Category
  |> Ash.Changeset.for_create(:create, cat, actor: admin)
  |> Ash.create!()
end

# --- Blog Posts ---
IO.puts("  Creating blog posts...")
posts = [
  %{
    title: "Introducing FounderPad: Ship SaaS in Days, Not Months",
    body: "<p>We're excited to launch FounderPad, the most complete SaaS boilerplate for Elixir and Phoenix.</p><p>With built-in authentication, billing, AI agent management, team collaboration, and more — you can focus on what makes your product unique instead of rebuilding the same infrastructure every startup needs.</p><h2>What's Included</h2><ul><li>Multi-tenant workspaces with RBAC</li><li>Stripe billing with 4-tier plans</li><li>AI agent orchestration (Anthropic + OpenAI)</li><li>Real-time notifications</li><li>Admin panel with impersonation</li></ul><p>Get started at <a href='/'>founderpad.io</a>.</p>",
    excerpt: "The most complete SaaS boilerplate for Elixir and Phoenix. Ship in days, not months.",
    status: :published,
    published_at: DateTime.utc_now(),
    category_id: Enum.at(blog_cats, 0).id
  },
  %{
    title: "Building AI Agents with FounderPad",
    body: "<p>Learn how to create, configure, and deploy AI agents using FounderPad's built-in agent management system.</p><h2>Creating Your First Agent</h2><p>Navigate to the Agents page and click 'New Agent'. Configure the system prompt, choose your provider (Anthropic or OpenAI), and set the model parameters.</p><h2>Best Practices</h2><ol><li>Write clear, specific system prompts</li><li>Set appropriate temperature (0.1-0.3 for factual, 0.7-0.9 for creative)</li><li>Use tool definitions for structured outputs</li><li>Monitor token usage in the analytics dashboard</li></ol>",
    excerpt: "Step-by-step guide to creating and deploying AI agents with FounderPad.",
    status: :published,
    published_at: DateTime.add(DateTime.utc_now(), -3 * 86400, :second),
    category_id: Enum.at(blog_cats, 2).id
  },
  %{
    title: "How We Built Real-Time Collaboration with Phoenix Presence",
    body: "<p>A deep dive into how FounderPad uses Phoenix Presence to enable real-time collaboration on agent configurations.</p><p>Phoenix Presence leverages CRDTs (Conflict-free Replicated Data Types) to track which users are online and what they're working on — all without a single database query.</p>",
    excerpt: "Technical deep dive into Phoenix Presence for real-time collaboration.",
    status: :draft,
    category_id: Enum.at(blog_cats, 1).id
  }
]

for post <- posts do
  p = Content.Post
  |> Ash.Changeset.for_create(:create, Map.put(post, :author_id, admin.id), actor: admin)
  |> Ash.create!()

  if post.status == :published do
    p |> Ash.Changeset.for_update(:publish, %{}, actor: admin) |> Ash.update!()
  end
end

# --- Changelog Entries ---
IO.puts("  Creating changelog entries...")
changelog = [
  %{version: "v2.0.0", title: "Production Features Release", body: "<ul><li>Blog CMS with WYSIWYG editor</li><li>SEO engine with JSON-LD structured data</li><li>Admin panel with user management</li><li>API key management</li><li>Help center with full-text search</li><li>Push notifications (FCM + Web Push)</li><li>OAuth social login</li><li>GDPR compliance tools</li></ul>", type: :feature},
  %{version: "v1.1.0", title: "Production Polish", body: "<ul><li>Working agent chat with PubSub streaming</li><li>Stripe checkout with graceful degradation</li><li>Notification system with email delivery</li></ul>", type: :improvement},
  %{version: "v1.0.0", title: "Initial Release", body: "<ul><li>Authentication (email/password + magic links)</li><li>Multi-tenant workspaces</li><li>AI agent CRUD</li><li>Stripe billing integration</li></ul>", type: :feature}
]

for entry <- changelog do
  e = Content.ChangelogEntry
  |> Ash.Changeset.for_create(:create, Map.put(entry, :author_id, admin.id), actor: admin)
  |> Ash.create!()

  e |> Ash.Changeset.for_update(:publish, %{}, actor: admin) |> Ash.update!()
end

# --- Help Center ---
IO.puts("  Creating help center content...")
help_categories = [
  %{name: "Getting Started", slug: "getting-started", description: "New to FounderPad? Start here.", icon: "rocket_launch", position: 0},
  %{name: "Billing & Plans", slug: "billing", description: "Manage your subscription and payments.", icon: "credit_card", position: 1},
  %{name: "AI Agents", slug: "agents", description: "Create and configure AI agents.", icon: "smart_toy", position: 2},
  %{name: "API & Integrations", slug: "api", description: "Connect to FounderPad programmatically.", icon: "code", position: 3},
  %{name: "Team & Workspaces", slug: "team", description: "Collaborate with your team.", icon: "group", position: 4},
  %{name: "Security", slug: "security", description: "Keep your account secure.", icon: "shield", position: 5}
]

help_cats = for cat <- help_categories do
  HelpCenter.Category
  |> Ash.Changeset.for_create(:create, cat, actor: admin)
  |> Ash.create!()
end

help_articles = [
  %{title: "Creating Your Account", slug: "creating-account", body: "Sign up at /auth/register with your email and a password. You'll receive a welcome email with tips to get started.", excerpt: "How to sign up for FounderPad", category_id: Enum.at(help_cats, 0).id, position: 0, help_context_key: "auth.register"},
  %{title: "Setting Up Your First Workspace", slug: "first-workspace", body: "After registration, the onboarding wizard guides you through creating your first organisation. Give it a name, invite team members, and choose a plan.", excerpt: "Create your organisation and invite your team", category_id: Enum.at(help_cats, 0).id, position: 1, help_context_key: "onboarding"},
  %{title: "Understanding Plans & Pricing", slug: "plans-pricing", body: "FounderPad offers 4 tiers: Free (1 agent, 1K API calls), Starter ($29/mo, 10 agents), Pro ($79/mo, 50 agents), Enterprise ($199/mo, unlimited). Upgrade anytime from the Billing page.", excerpt: "Compare plans and pricing", category_id: Enum.at(help_cats, 1).id, position: 0, help_context_key: "billing.plans"},
  %{title: "Managing API Keys", slug: "api-keys", body: "Generate API keys from the API Keys page. Each key has scoped permissions (read, write, admin). Keys are shown once on creation — save them securely. Revoke compromised keys immediately.", excerpt: "Create, manage, and revoke API keys", category_id: Enum.at(help_cats, 3).id, position: 0, help_context_key: "api-keys"},
  %{title: "Enabling Two-Factor Authentication", slug: "two-factor-auth", body: "Go to Settings → Two-Factor Authentication. Scan the QR code with your authenticator app (Google Authenticator, Authy). Enter the 6-digit code to verify. Save your backup codes in a secure location.", excerpt: "Secure your account with 2FA", category_id: Enum.at(help_cats, 5).id, position: 0, help_context_key: "settings.two-factor"}
]

for article <- help_articles do
  a = HelpCenter.Article
  |> Ash.Changeset.for_create(:create, article, actor: admin)
  |> Ash.create!()

  a |> Ash.Changeset.for_update(:publish, %{}, actor: admin) |> Ash.update!()
end

# --- Agent Templates ---
IO.puts("  Creating agent templates...")
templates = [
  %{name: "Customer Support Bot", description: "Handles common customer inquiries, FAQ lookups, and ticket routing.", category: "Support", system_prompt: "You are a helpful customer support agent for a SaaS product. Answer questions clearly and concisely. If you can't help, offer to escalate to a human agent.", icon: "support_agent", featured: true},
  %{name: "Code Review Assistant", description: "Reviews code for bugs, style issues, and suggests improvements.", category: "Engineering", system_prompt: "You are an expert code reviewer. Analyze the provided code for bugs, security issues, performance problems, and style inconsistencies. Provide specific, actionable feedback with code examples.", icon: "code", featured: true},
  %{name: "Content Writer", description: "Generates blog posts, social media content, and marketing copy.", category: "Marketing", system_prompt: "You are a skilled content writer. Create engaging, well-structured content that is SEO-friendly and matches the brand voice. Include relevant keywords naturally.", icon: "edit_note", featured: true},
  %{name: "Data Analyst", description: "Analyzes data, creates summaries, and identifies trends.", category: "Analytics", system_prompt: "You are a data analyst. Analyze the provided data, identify patterns and trends, and present findings in a clear, actionable format with specific recommendations.", icon: "analytics", featured: false},
  %{name: "Meeting Summarizer", description: "Summarizes meeting transcripts into action items and key decisions.", category: "Productivity", system_prompt: "You are a meeting summarizer. Extract key decisions, action items with owners, and important discussion points from meeting transcripts. Format as a structured summary.", icon: "summarize", featured: false}
]

for tmpl <- templates do
  AI.AgentTemplate
  |> Ash.Changeset.for_create(:create, tmpl, actor: admin)
  |> Ash.create!()
end

IO.puts("✅ Seed complete!")
IO.puts("")
IO.puts("  Admin login:  admin@founderpad.io / Admin123!")
IO.puts("  Demo login:   demo@founderpad.io / Demo123!")
IO.puts("  Organisation: Acme Corp")
