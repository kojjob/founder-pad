defmodule LinkHubWeb.Router do
  @moduledoc "Phoenix router defining all application routes and pipelines."
  use LinkHubWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LinkHubWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug LinkHubWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
  end

  # Auth session controller (sets/clears session cookie)
  scope "/auth", LinkHubWeb do
    pipe_through :browser
    get "/session", AuthSessionController, :create
    delete "/session", AuthSessionController, :delete
  end

  # Auth routes (no layout - full-page auth screens)
  scope "/auth", LinkHubWeb.Auth do
    pipe_through :browser
    live "/login", LoginLive
    live "/register", RegisterLive
  end

  scope "/", LinkHubWeb do
    pipe_through :browser

    get "/sitemap.xml", SitemapController, :index
    post "/checkout/:plan_slug", CheckoutController, :create
    live "/", LandingLive
    live "/docs", Docs.DocsLive
    live "/docs/api", Docs.ApiSpecsLive
    live "/docs/changelog", Docs.ChangelogLive

    # App routes with sidebar layout
    live_session :app,
      layout: {LinkHubWeb.Layouts, :app},
      on_mount: [
        {LinkHubWeb.Hooks.AssignDefaults, :default},
        {LinkHubWeb.Hooks.RequireAuth, :default},
        {LinkHubWeb.Hooks.NotificationHandler, :default}
      ] do
      live "/dashboard", DashboardLive
      live "/activity", ActivityLive
      live "/workspaces", WorkspacesLive
      live "/agents", AgentsLive
      live "/agents/new", AgentCreateLive
      live "/agents/:id", AgentDetailLive
      live "/billing", BillingLive
      live "/team", TeamLive
      live "/settings", SettingsLive
      live "/channels", ChannelLive
      live "/channels/:id", ChannelLive
      live "/files", FileBrowserLive
    end

    live "/onboarding", OnboardingLive
  end

  # Public share link routes — no auth needed
  scope "/s", LinkHubWeb do
    pipe_through [:browser]

    get "/:token", ShareLinkController, :show
    post "/:token/unlock", ShareLinkController, :unlock
  end

  # Authenticated upload API (session-based auth via browser pipeline)
  scope "/api/uploads", LinkHubWeb do
    pipe_through [:browser, LinkHubWeb.Plugs.Auth]

    post "/initiate", UploadController, :initiate
    post "/complete", UploadController, :complete
    get "/:file_id/url", UploadController, :get_url
  end

  # Webhook routes (no CSRF, raw body needed)
  scope "/webhooks", LinkHubWeb do
    pipe_through :api
    post "/stripe", WebhookController, :stripe
  end

  # JSON:API (REST) — auto-derived from Ash resources
  scope "/api/v1" do
    pipe_through :api
    forward "/", LinkHubWeb.Api.JsonApiRouter
  end

  # GraphQL — auto-derived from Ash resources
  scope "/api" do
    pipe_through :api
    forward "/graphql", Absinthe.Plug, schema: LinkHubWeb.Api.GraphqlSchema

    if Application.compile_env(:link_hub, :dev_routes) do
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: LinkHubWeb.Api.GraphqlSchema,
        interface: :playground
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:link_hub, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LinkHubWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
