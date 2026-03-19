defmodule FounderPadWeb.LandingLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "FounderPad — Ship Your SaaS in Days, Not Months",
       meta_description:
         "The production-ready Phoenix boilerplate with built-in AI agents, Stripe billing, team management, and beautiful dark/light UI. Ship your SaaS in days, not months.",
       og_title: "FounderPad — Ship Your SaaS in Days, Not Months",
       og_description:
         "Production-ready Phoenix boilerplate with AI agents, Stripe billing, team management, and dark/light UI.",
       og_image: "/images/og-founderpad.png",
       twitter_card: "summary_large_image"
     ), layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary">
      <%!-- ═══════════════════════════════════════════════════════
           NAVIGATION — Sticky glass nav bar
           ═══════════════════════════════════════════════════════ --%>
      <nav class="fixed top-0 inset-x-0 z-50 bg-background/60 backdrop-blur-md">
        <div class="max-w-7xl mx-auto flex items-center justify-between px-6 py-4">
          <%!-- Logo --%>
          <a href="/" class="flex items-center gap-2.5">
            <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
              <span class="material-symbols-outlined text-on-primary text-lg">architecture</span>
            </div>
            <span class="text-xl font-extrabold font-headline tracking-tight text-on-surface">FounderPad</span>
          </a>

          <%!-- Desktop nav links --%>
          <div class="hidden md:flex items-center gap-8 text-sm font-medium text-on-surface-variant">
            <a href="#features" class="hover:text-on-surface transition-colors">Features</a>
            <a href="#pricing" class="hover:text-on-surface transition-colors">Pricing</a>
            <a href="https://docs.founderpad.io" target="_blank" class="hover:text-on-surface transition-colors">Docs</a>
            <a href="/auth/login" class="hover:text-on-surface transition-colors">Login</a>
          </div>

          <%!-- Right side: CTA + Theme toggle --%>
          <div class="flex items-center gap-3">
            <a href="/auth/register" class="hidden sm:inline-flex items-center px-5 py-2 rounded-lg text-sm font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95">
              Get Started
            </a>
            <button id="theme-toggle-landing" phx-hook="ThemeToggle" class="p-2 text-on-surface-variant hover:text-on-surface transition-colors cursor-pointer rounded-lg hover:bg-surface-container-high/50">
              <span class="material-symbols-outlined text-xl">dark_mode</span>
            </button>
          </div>
        </div>
      </nav>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 1: HERO — Full viewport, commanding presence
           ═══════════════════════════════════════════════════════ --%>
      <section class="relative min-h-screen flex items-center px-6 pt-24 pb-16 overflow-hidden">
        <%!-- Background glows --%>
        <div class="absolute top-1/4 left-1/4 w-[600px] h-[600px] bg-primary/5 rounded-full blur-[120px] pointer-events-none"></div>
        <div class="absolute bottom-1/4 right-1/4 w-[400px] h-[400px] bg-secondary/5 rounded-full blur-[100px] pointer-events-none"></div>

        <div class="relative max-w-[1280px] mx-auto w-full grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          <%!-- Left Column: Copy --%>
          <div class="space-y-8">
            <%!-- Announcement bar --%>
            <div class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-surface-container text-xs font-medium text-on-surface-variant">
              <span class="text-secondary">&#x1F680;</span>
              <span>v1.0 — Now with multi-provider AI agents</span>
              <span class="material-symbols-outlined text-sm text-primary">arrow_forward</span>
            </div>

            <%!-- Headline --%>
            <h1 class="text-5xl sm:text-6xl lg:text-7xl font-extrabold font-headline tracking-tight leading-[1.05]">
              Ship Your SaaS
              <br />
              <span class="text-primary">In Days, Not Months.</span>
            </h1>

            <%!-- Subheadline --%>
            <p class="text-lg sm:text-xl text-on-surface-variant max-w-xl leading-relaxed">
              The production-ready Phoenix boilerplate with built-in AI agents, Stripe billing, team management, and beautiful dark/light UI.
            </p>

            <%!-- CTA Buttons --%>
            <div class="flex flex-col sm:flex-row items-start gap-4">
              <a href="/auth/register" class="inline-flex items-center gap-2 px-8 py-3.5 rounded-xl text-base font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95 editorial-shadow">
                <span>Get Started Free</span>
                <span class="material-symbols-outlined text-lg">arrow_forward</span>
              </a>
              <a href="https://github.com/founderpad" target="_blank" class="inline-flex items-center gap-2 px-8 py-3.5 rounded-xl text-base font-semibold text-on-surface bg-surface-container hover:bg-surface-container-high transition-colors">
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12Z"/></svg>
                <span>View on GitHub</span>
              </a>
            </div>

            <%!-- Social proof --%>
            <div class="flex flex-col sm:flex-row items-start gap-4 text-sm text-on-surface-variant">
              <div class="flex -space-x-2">
                <div class="w-8 h-8 rounded-full bg-primary-container flex items-center justify-center text-[10px] font-bold text-on-primary-container ring-2 ring-background">JD</div>
                <div class="w-8 h-8 rounded-full bg-secondary-container flex items-center justify-center text-[10px] font-bold text-on-secondary-container ring-2 ring-background">SC</div>
                <div class="w-8 h-8 rounded-full bg-tertiary-container flex items-center justify-center text-[10px] font-bold text-on-tertiary ring-2 ring-background">AL</div>
                <div class="w-8 h-8 rounded-full bg-primary-fixed-dim flex items-center justify-center text-[10px] font-bold text-on-primary-fixed ring-2 ring-background">MR</div>
                <div class="w-8 h-8 rounded-full bg-surface-container-highest flex items-center justify-center text-[10px] font-bold text-on-surface ring-2 ring-background">+</div>
              </div>
              <div class="space-y-1">
                <span>Trusted by <strong class="text-on-surface">500+</strong> founders</span>
                <div class="flex items-center gap-0.5 text-secondary">
                  <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                  <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                  <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                  <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                  <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star_half</span>
                  <span class="text-on-surface-variant text-xs ml-1">4.8/5</span>
                </div>
              </div>
            </div>
          </div>

          <%!-- Right Column: Dashboard Screenshot --%>
          <div class="relative">
            <div class="rounded-2xl overflow-hidden editorial-shadow ring-1 ring-outline-variant/10">
              <img
                src="/images/dashboard-preview.png"
                alt="FounderPad Dashboard — AI agent orchestration, billing metrics, and team activity in the Midnight Architect dark theme"
                class="w-full h-auto"
                width="1280"
                height="1024"
                loading="eager"
              />
            </div>
            <%!-- Glow under image --%>
            <div class="absolute -bottom-6 left-1/2 -translate-x-1/2 w-3/4 h-12 bg-primary/15 blur-[50px] rounded-full pointer-events-none"></div>
            <%!-- Floating badges --%>
            <div class="absolute -bottom-4 -left-4 bg-surface-container-lowest glass-effect rounded-xl px-4 py-2.5 editorial-shadow flex items-center gap-2 z-10">
              <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              <span class="text-xs font-mono text-on-surface">123 tests passing</span>
            </div>
            <div class="absolute -top-4 -right-4 bg-surface-container-lowest glass-effect rounded-xl px-4 py-2.5 editorial-shadow flex items-center gap-2 z-10">
              <span class="material-symbols-outlined text-primary text-sm">bolt</span>
              <span class="text-xs font-mono text-on-surface">8 Ash domains</span>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 2: LOGOS BAR — Built with trust signals
           ═══════════════════════════════════════════════════════ --%>
      <section class="py-16 px-6">
        <div class="max-w-5xl mx-auto text-center">
          <p class="text-xs uppercase tracking-[0.2em] text-on-surface-variant/50 font-medium mb-8">Built with</p>
          <div class="flex flex-wrap items-center justify-center gap-x-10 gap-y-4 text-on-surface-variant/40 font-mono text-sm font-medium">
            <span>Phoenix</span>
            <span class="text-outline-variant/30">&bull;</span>
            <span>Elixir</span>
            <span class="text-outline-variant/30">&bull;</span>
            <span>Ash Framework</span>
            <span class="text-outline-variant/30">&bull;</span>
            <span>Stripe</span>
            <span class="text-outline-variant/30">&bull;</span>
            <span>Tailwind CSS</span>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 3: FEATURES GRID — Asymmetric bento layout
           ═══════════════════════════════════════════════════════ --%>
      <section id="features" class="py-24 px-6">
        <div class="max-w-7xl mx-auto">
          <div class="text-center mb-16">
            <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">Features</p>
            <h2 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight">Everything you need to ship</h2>
            <p class="mt-4 text-lg text-on-surface-variant max-w-2xl mx-auto">
              Stop wiring boilerplate. Start building your product from day one.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            <%!-- Feature 1: AI Agents — Large card --%>
            <div class="lg:col-span-2 bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01] group">
              <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-primary text-2xl">smart_toy</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">AI Agent Orchestration</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Multi-provider support for Claude and GPT-4o with real-time streaming, tool calls, and conversation history. Built on a composable agent framework that scales.
              </p>
              <div class="mt-5 flex flex-wrap gap-2">
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">Streaming</span>
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">Tool Calls</span>
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">Multi-Provider</span>
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">Conversation Memory</span>
              </div>
            </div>

            <%!-- Feature 2: Stripe Billing --%>
            <div class="bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01]">
              <div class="w-12 h-12 rounded-xl bg-secondary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-secondary text-2xl">payments</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">Stripe Billing</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Plans, subscriptions, usage metering, and webhook processing — all pre-wired and production-tested.
              </p>
            </div>

            <%!-- Feature 3: Team Management --%>
            <div class="bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01]">
              <div class="w-12 h-12 rounded-xl bg-tertiary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-tertiary text-2xl">group</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">Team Management</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Roles, invitations, and org-scoped tenancy out of the box. Invite teammates and manage permissions seamlessly.
              </p>
            </div>

            <%!-- Feature 4: Dark & Light Mode — Large card --%>
            <div class="lg:col-span-2 bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01]">
              <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-primary text-2xl">dark_mode</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">Dark &amp; Light Mode</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Stitch-designed theming with a polished theme toggle, system preference detection, and the Indigo Slate Protocol design system built on tonal layering.
              </p>
              <div class="mt-5 flex flex-wrap gap-2">
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">System Preference</span>
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">Tonal Surfaces</span>
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">Design Tokens</span>
              </div>
            </div>

            <%!-- Feature 5: API Layer --%>
            <div class="bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01]">
              <div class="w-12 h-12 rounded-xl bg-secondary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-secondary text-2xl">api</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">API Layer</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Auto-derived REST and GraphQL endpoints from Ash resources. Define once, expose everywhere.
              </p>
            </div>

            <%!-- Feature 6: Production Ready --%>
            <div class="bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01]">
              <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-primary text-2xl">rocket_launch</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">Production Ready</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Docker, Fly.io config, CI/CD pipelines, audit logs, and rate limiting — deploy with confidence from day one.
              </p>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 4: METRICS — Social proof numbers
           ═══════════════════════════════════════════════════════ --%>
      <section class="py-24 px-6">
        <div class="max-w-5xl mx-auto">
          <div class="grid grid-cols-2 md:grid-cols-4 gap-8 text-center">
            <div class="space-y-2">
              <p class="text-5xl font-mono font-bold text-on-surface">8</p>
              <p class="text-sm text-on-surface-variant font-medium">Ash Domains</p>
            </div>
            <div class="space-y-2">
              <p class="text-5xl font-mono font-bold text-on-surface">123</p>
              <p class="text-sm text-on-surface-variant font-medium">Tests Passing</p>
            </div>
            <div class="space-y-2">
              <p class="text-5xl font-mono font-bold text-on-surface">19+</p>
              <p class="text-sm text-on-surface-variant font-medium">Database Tables</p>
            </div>
            <div class="space-y-2">
              <p class="text-5xl font-mono font-bold text-on-surface">12</p>
              <p class="text-sm text-on-surface-variant font-medium">LiveView Screens</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 5: CODE PREVIEW — Developer experience
           ═══════════════════════════════════════════════════════ --%>
      <section class="py-24 px-6">
        <div class="max-w-3xl mx-auto">
          <div class="text-center mb-12">
            <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">Developer Experience</p>
            <h2 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight">Three commands. Ship it.</h2>
          </div>

          <div class="bg-surface-container rounded-xl p-6 sm:p-8 editorial-shadow ring-1 ring-outline-variant/10">
            <div class="flex items-center gap-2 mb-5">
              <div class="w-3 h-3 rounded-full bg-error/60"></div>
              <div class="w-3 h-3 rounded-full bg-secondary/60"></div>
              <div class="w-3 h-3 rounded-full bg-primary/40"></div>
              <span class="ml-3 text-xs text-on-surface-variant/50 font-mono">terminal</span>
            </div>
            <pre class="font-mono text-sm leading-relaxed overflow-x-auto"><code><span class="text-on-surface-variant/50">$</span> <span class="text-primary">mix</span> phx.new my_app          <span class="text-on-surface-variant/40"># scaffold</span>
<span class="text-on-surface-variant/50">$</span> <span class="text-primary">mix</span> founder_pad.setup       <span class="text-on-surface-variant/40"># configure everything</span>
<span class="text-on-surface-variant/50">$</span> <span class="text-primary">mix</span> phx.server              <span class="text-on-surface-variant/40"># ship it</span></code></pre>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 6: PRICING — 4 tiers
           ═══════════════════════════════════════════════════════ --%>
      <section id="pricing" class="py-24 px-6">
        <div class="max-w-7xl mx-auto">
          <div class="text-center mb-16">
            <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">Pricing</p>
            <h2 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight">Simple, transparent pricing</h2>
            <p class="mt-4 text-lg text-on-surface-variant max-w-2xl mx-auto">
              Start free. Scale when you're ready.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
            <%!-- Free tier --%>
            <div class="bg-surface-container rounded-xl p-8 flex flex-col transition-transform hover:scale-[1.01]">
              <h3 class="text-lg font-bold font-headline">Free</h3>
              <div class="mt-4 mb-6">
                <span class="text-4xl font-mono font-bold text-on-surface">$0</span>
                <span class="text-on-surface-variant text-sm">/month</span>
              </div>
              <ul class="space-y-3 text-sm text-on-surface-variant flex-1">
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>1 AI Agent</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>1,000 API calls/mo</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>1 Team member</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Community support</li>
              </ul>
              <a href="/auth/register" class="mt-8 inline-flex items-center justify-center px-6 py-3 rounded-xl text-sm font-semibold border border-outline-variant/30 text-on-surface hover:bg-surface-container-high transition-colors">
                Get Started
              </a>
            </div>

            <%!-- Starter tier --%>
            <div class="bg-surface-container rounded-xl p-8 flex flex-col transition-transform hover:scale-[1.01]">
              <h3 class="text-lg font-bold font-headline">Starter</h3>
              <div class="mt-4 mb-6">
                <span class="text-4xl font-mono font-bold text-on-surface">$29</span>
                <span class="text-on-surface-variant text-sm">/month</span>
              </div>
              <ul class="space-y-3 text-sm text-on-surface-variant flex-1">
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>5 AI Agents</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>10,000 API calls/mo</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>5 Team members</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Email support</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Custom branding</li>
              </ul>
              <a href="/auth/register" class="mt-8 inline-flex items-center justify-center px-6 py-3 rounded-xl text-sm font-semibold border border-outline-variant/30 text-on-surface hover:bg-surface-container-high transition-colors">
                Start Free Trial
              </a>
            </div>

            <%!-- Pro tier — Highlighted --%>
            <div class="relative bg-surface-container rounded-xl p-8 flex flex-col ring-2 ring-primary transition-transform hover:scale-[1.01]">
              <div class="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-0.5 rounded-full primary-gradient text-xs font-bold">
                Most Popular
              </div>
              <h3 class="text-lg font-bold font-headline">Pro</h3>
              <div class="mt-4 mb-6">
                <span class="text-4xl font-mono font-bold text-on-surface">$79</span>
                <span class="text-on-surface-variant text-sm">/month</span>
              </div>
              <ul class="space-y-3 text-sm text-on-surface-variant flex-1">
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Unlimited AI Agents</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>100,000 API calls/mo</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Unlimited Team members</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Priority support</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Advanced analytics</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>API access</li>
              </ul>
              <a href="/auth/register" class="mt-8 inline-flex items-center justify-center px-6 py-3 rounded-xl text-sm font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95">
                Start Free Trial
              </a>
            </div>

            <%!-- Enterprise tier --%>
            <div class="bg-surface-container rounded-xl p-8 flex flex-col transition-transform hover:scale-[1.01]">
              <h3 class="text-lg font-bold font-headline">Enterprise</h3>
              <div class="mt-4 mb-6">
                <span class="text-4xl font-mono font-bold text-on-surface">$199</span>
                <span class="text-on-surface-variant text-sm">/month</span>
              </div>
              <ul class="space-y-3 text-sm text-on-surface-variant flex-1">
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Everything in Pro</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Unlimited API calls</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>SSO &amp; SAML</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Dedicated support</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Custom integrations</li>
                <li class="flex items-start gap-2"><span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>SLA guarantee</li>
              </ul>
              <a href="/auth/register" class="mt-8 inline-flex items-center justify-center px-6 py-3 rounded-xl text-sm font-semibold border border-outline-variant/30 text-on-surface hover:bg-surface-container-high transition-colors">
                Contact Sales
              </a>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 7: TESTIMONIALS — 3 editorial quotes
           ═══════════════════════════════════════════════════════ --%>
      <section class="py-24 px-6">
        <div class="max-w-7xl mx-auto">
          <div class="text-center mb-16">
            <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">Testimonials</p>
            <h2 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight">Loved by founders</h2>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
            <div class="bg-surface-container rounded-xl p-8 editorial-shadow">
              <div class="flex items-center gap-1 mb-5 text-secondary">
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
              </div>
              <blockquote class="text-on-surface leading-relaxed mb-6">
                "FounderPad saved us 3 months of setup work. The AI agent framework alone was worth it — we had multi-provider streaming running in under an hour."
              </blockquote>
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-primary-container flex items-center justify-center text-xs font-bold text-on-primary-container">JK</div>
                <div>
                  <p class="text-sm font-semibold text-on-surface">James Kowalski</p>
                  <p class="text-xs text-on-surface-variant">CTO, DataSync AI</p>
                </div>
              </div>
            </div>

            <div class="bg-surface-container rounded-xl p-8 editorial-shadow">
              <div class="flex items-center gap-1 mb-5 text-secondary">
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
              </div>
              <blockquote class="text-on-surface leading-relaxed mb-6">
                "The Stripe integration is flawless. Subscriptions, usage metering, webhooks — everything just works. We launched our billing on day two."
              </blockquote>
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-secondary-container flex items-center justify-center text-xs font-bold text-on-secondary-container">SP</div>
                <div>
                  <p class="text-sm font-semibold text-on-surface">Sarah Park</p>
                  <p class="text-xs text-on-surface-variant">Founder, InvoiceFlow</p>
                </div>
              </div>
            </div>

            <div class="bg-surface-container rounded-xl p-8 editorial-shadow">
              <div class="flex items-center gap-1 mb-5 text-secondary">
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
                <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1">star</span>
              </div>
              <blockquote class="text-on-surface leading-relaxed mb-6">
                "Best dark mode I've ever seen in a boilerplate. The design system is incredibly polished — our designers were impressed from the first screenshot."
              </blockquote>
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-tertiary-container flex items-center justify-center text-xs font-bold text-on-tertiary">ML</div>
                <div>
                  <p class="text-sm font-semibold text-on-surface">Marcus Lee</p>
                  <p class="text-xs text-on-surface-variant">CEO, NightOwl Labs</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 8: CTA — Final conversion push
           ═══════════════════════════════════════════════════════ --%>
      <section class="py-24 px-6">
        <div class="max-w-4xl mx-auto text-center">
          <div class="bg-surface-container rounded-2xl p-12 sm:p-16 relative overflow-hidden">
            <%!-- Background glow --%>
            <div class="absolute top-0 right-0 w-80 h-80 bg-primary/5 rounded-full blur-[100px] pointer-events-none"></div>
            <div class="absolute bottom-0 left-0 w-60 h-60 bg-secondary/5 rounded-full blur-[80px] pointer-events-none"></div>

            <div class="relative">
              <h2 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight">Ready to ship your SaaS?</h2>
              <p class="mt-4 text-lg text-on-surface-variant">Get started in under 5 minutes.</p>
              <div class="mt-8 flex flex-col sm:flex-row items-center justify-center gap-4">
                <a href="/auth/register" class="inline-flex items-center gap-2 px-8 py-3.5 rounded-xl text-base font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95 editorial-shadow">
                  <span>Get Started Free</span>
                  <span class="material-symbols-outlined text-lg">arrow_forward</span>
                </a>
              </div>
              <p class="mt-4 text-sm text-on-surface-variant/60">No credit card required</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 9: FOOTER
           ═══════════════════════════════════════════════════════ --%>
      <footer class="py-16 px-6 border-t border-outline-variant/10">
        <div class="max-w-7xl mx-auto">
          <div class="grid grid-cols-2 md:grid-cols-4 gap-8 mb-12">
            <%!-- Product --%>
            <div>
              <h4 class="text-sm font-semibold font-headline text-on-surface mb-4">Product</h4>
              <ul class="space-y-2.5 text-sm text-on-surface-variant">
                <li><a href="#features" class="hover:text-on-surface transition-colors">Features</a></li>
                <li><a href="#pricing" class="hover:text-on-surface transition-colors">Pricing</a></li>
                <li><a href="/dashboard" class="hover:text-on-surface transition-colors">Dashboard</a></li>
                <li><a href="/agents" class="hover:text-on-surface transition-colors">AI Agents</a></li>
              </ul>
            </div>

            <%!-- Resources --%>
            <div>
              <h4 class="text-sm font-semibold font-headline text-on-surface mb-4">Resources</h4>
              <ul class="space-y-2.5 text-sm text-on-surface-variant">
                <li><a href="https://docs.founderpad.io" target="_blank" class="hover:text-on-surface transition-colors">Documentation</a></li>
                <li><a href="https://founderpad.io/changelog" target="_blank" class="hover:text-on-surface transition-colors">Changelog</a></li>
                <li><a href="/api/v1/open_api" class="hover:text-on-surface transition-colors">API Reference</a></li>
                <li><a href="https://github.com/founderpad" target="_blank" class="hover:text-on-surface transition-colors">GitHub</a></li>
              </ul>
            </div>

            <%!-- Company --%>
            <div>
              <h4 class="text-sm font-semibold font-headline text-on-surface mb-4">Company</h4>
              <ul class="space-y-2.5 text-sm text-on-surface-variant">
                <li><a href="#" class="hover:text-on-surface transition-colors">About</a></li>
                <li><a href="#" class="hover:text-on-surface transition-colors">Blog</a></li>
                <li><a href="#" class="hover:text-on-surface transition-colors">Careers</a></li>
                <li><a href="mailto:support@founderpad.io" class="hover:text-on-surface transition-colors">Contact</a></li>
              </ul>
            </div>

            <%!-- Legal --%>
            <div>
              <h4 class="text-sm font-semibold font-headline text-on-surface mb-4">Legal</h4>
              <ul class="space-y-2.5 text-sm text-on-surface-variant">
                <li><a href="#" class="hover:text-on-surface transition-colors">Privacy Policy</a></li>
                <li><a href="#" class="hover:text-on-surface transition-colors">Terms of Service</a></li>
                <li><a href="#" class="hover:text-on-surface transition-colors">Cookie Policy</a></li>
              </ul>
            </div>
          </div>

          <%!-- Bottom bar --%>
          <div class="pt-8 border-t border-outline-variant/10 flex flex-col sm:flex-row items-center justify-between gap-4">
            <div class="flex items-center gap-2.5">
              <div class="w-6 h-6 rounded-md bg-primary flex items-center justify-center">
                <span class="material-symbols-outlined text-on-primary text-sm">architecture</span>
              </div>
              <span class="text-xs font-mono text-on-surface-variant">&copy; 2026 FounderPad. All rights reserved.</span>
            </div>
            <div class="flex items-center gap-4">
              <a href="https://github.com/founderpad" target="_blank" class="text-on-surface-variant hover:text-on-surface transition-colors">
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12Z"/></svg>
              </a>
              <a href="https://twitter.com/founderpad" target="_blank" class="text-on-surface-variant hover:text-on-surface transition-colors">
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
              </a>
              <a href="https://discord.gg/founderpad" target="_blank" class="text-on-surface-variant hover:text-on-surface transition-colors">
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028 14.09 14.09 0 0 0 1.226-1.994.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418z"/></svg>
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
    """
  end
end
