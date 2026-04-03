defmodule FounderPadWeb.Router do
  use FounderPadWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FounderPadWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug FounderPadWeb.Plugs.ApiKeyAuth
    plug FounderPadWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
  end

  pipeline :api_public do
    plug :accepts, ["json"]
  end

  # Auth session controller (sets/clears session cookie)
  scope "/auth", FounderPadWeb do
    pipe_through :browser
    get "/session", AuthSessionController, :create
    delete "/session", AuthSessionController, :delete
    get "/oauth/:provider/callback", OAuthCallbackController, :callback
  end

  # Auth routes (no layout - full-page auth screens)
  scope "/auth", FounderPadWeb.Auth do
    pipe_through :browser
    live "/login", LoginLive
    live "/register", RegisterLive
  end

  # Unsubscribe route (public, no auth required)
  scope "/", FounderPadWeb do
    pipe_through :browser
    get "/unsubscribe/:token", UnsubscribeController, :unsubscribe
  end

  # RSS feed routes (controller, not LiveView)
  scope "/", FounderPadWeb do
    pipe_through :browser
    get "/blog/feed.xml", FeedController, :blog_feed
    get "/changelog/feed.xml", FeedController, :changelog_feed
  end

  # Public blog routes
  scope "/blog", FounderPadWeb.Blog do
    pipe_through :browser
    live "/", BlogIndexLive
    live "/category/:slug", BlogCategoryLive
    live "/tag/:slug", BlogTagLive
    live "/:slug", BlogPostLive
  end

  # Help center routes (public, no auth required)
  scope "/help", FounderPadWeb.Help do
    pipe_through :browser
    live "/", HelpIndexLive
    live "/search", HelpSearchLive
    live "/contact", HelpContactLive
    live "/:category_slug", HelpCategoryLive
    live "/:category_slug/:slug", HelpArticleLive
  end

  scope "/", FounderPadWeb do
    pipe_through :browser

    live "/privacy", PrivacyLive
    live "/terms", TermsLive
    get "/sitemap.xml", SitemapController, :index
    post "/checkout/:plan_slug", CheckoutController, :create
    live "/", LandingLive
    live "/docs", Docs.DocsLive
    live "/docs/api", Docs.ApiSpecsLive
    live "/docs/changelog", Docs.ChangelogLive

    # App routes with sidebar layout
    live_session :app,
      layout: {FounderPadWeb.Layouts, :app},
      on_mount: [
        {FounderPadWeb.Hooks.AssignDefaults, :default},
        {FounderPadWeb.Hooks.RequireAuth, :default},
        {FounderPadWeb.Hooks.NotificationHandler, :default}
      ] do
      live "/dashboard", DashboardLive
      live "/activity", ActivityLive
      live "/workspaces", WorkspacesLive
      live "/agents", AgentsLive
      live "/agents/new", AgentCreateLive
      live "/agents/:id", AgentDetailLive
      live "/agents/:id/analytics", AgentAnalyticsLive
      live "/billing", BillingLive
      live "/team", TeamLive
      live "/settings", SettingsLive
      live "/api-keys", ApiKeysLive
    end

    # Admin impersonation controller routes (must be before live_session)
    scope "/admin", Admin do
      get "/impersonate/:id", ImpersonationController, :start
      get "/stop-impersonation", ImpersonationController, :stop
    end

    # Admin routes with admin authorization
    live_session :admin,
      layout: {FounderPadWeb.Layouts, :app},
      on_mount: [
        {FounderPadWeb.Hooks.AssignDefaults, :default},
        {FounderPadWeb.Hooks.RequireAuth, :default},
        {FounderPadWeb.Hooks.RequireAdmin, :default}
      ] do
      scope "/admin", Admin do
        live "/", AdminDashboardLive
        live "/users", UsersLive
        live "/users/:id", UserDetailLive
        live "/organisations", OrganisationsLive
        live "/subscriptions", SubscriptionsLive
        live "/feature-flags", FeatureFlagsLive
        live "/blog", BlogListLive
        live "/blog/new", BlogEditorLive
        live "/blog/:id/edit", BlogEditorLive
        live "/blog/categories", BlogCategoriesLive
        live "/blog/tags", BlogTagsLive
        live "/changelog", ChangelogListLive
        live "/changelog/new", ChangelogEditorLive
        live "/changelog/:id/edit", ChangelogEditorLive
        live "/seo", SeoDashboardLive
        live "/help", HelpArticlesLive
        live "/help/new", HelpArticleEditorLive
        live "/help/:id/edit", HelpArticleEditorLive
      end
    end

    live "/onboarding", OnboardingLive
  end

  # Global search API (no API key required)
  scope "/api", FounderPadWeb do
    pipe_through :api_public
    get "/search", SearchController, :search
  end

  # Push notification subscription (no API key required)
  scope "/api/push", FounderPadWeb do
    pipe_through :api_public
    post "/subscribe", PushSubscriptionController, :create
  end

  # Public privacy API (no API key required)
  scope "/api/privacy", FounderPadWeb do
    pipe_through :api_public
    post "/cookie-consent", CookieConsentController, :create
  end

  # Webhook routes (no CSRF, raw body needed)
  scope "/webhooks", FounderPadWeb do
    pipe_through :api
    post "/stripe", WebhookController, :stripe
  end

  # JSON:API (REST) — auto-derived from Ash resources
  scope "/api/v1" do
    pipe_through :api
    forward "/", FounderPadWeb.Api.JsonApiRouter
  end

  # GraphQL — auto-derived from Ash resources
  scope "/api" do
    pipe_through :api
    forward "/graphql", Absinthe.Plug, schema: FounderPadWeb.Api.GraphqlSchema

    if Application.compile_env(:founder_pad, :dev_routes) do
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: FounderPadWeb.Api.GraphqlSchema,
        interface: :playground
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:founder_pad, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FounderPadWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
