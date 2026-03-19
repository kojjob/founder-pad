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
    plug FounderPadWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
  end

  # Auth session controller (sets/clears session cookie)
  scope "/auth", FounderPadWeb do
    pipe_through :browser
    get "/session", AuthSessionController, :create
    delete "/session", AuthSessionController, :delete
  end

  # Auth routes (no layout - full-page auth screens)
  scope "/auth", FounderPadWeb.Auth do
    pipe_through :browser
    live "/login", LoginLive
    live "/register", RegisterLive
  end

  scope "/", FounderPadWeb do
    pipe_through :browser

    get "/sitemap.xml", SitemapController, :index
    live "/", LandingLive

    # App routes with sidebar layout
    live_session :app,
      layout: {FounderPadWeb.Layouts, :app},
      on_mount: [
        {FounderPadWeb.Hooks.AssignDefaults, :default},
        {FounderPadWeb.Hooks.RequireAuth, :default}
      ] do
      live "/dashboard", DashboardLive
      live "/activity", ActivityLive
      live "/workspaces", WorkspacesLive
      live "/agents", AgentsLive
      live "/agents/:id", AgentDetailLive
      live "/billing", BillingLive
      live "/team", TeamLive
      live "/settings", SettingsLive
    end

    live "/onboarding", OnboardingLive
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
