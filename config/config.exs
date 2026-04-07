# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :link_hub,
  env: config_env(),
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :link_hub, LinkHubWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LinkHubWeb.ErrorHTML, json: LinkHubWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LinkHub.PubSub,
  live_view: [signing_salt: "MnhgwL4O"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :link_hub, LinkHub.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  link_hub: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  link_hub: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Ash Framework
config :link_hub,
  ash_domains: [
    LinkHub.Accounts,
    LinkHub.Messaging,
    LinkHub.Media,
    LinkHub.Billing,
    LinkHub.AI,
    LinkHub.Notifications,
    LinkHub.Audit,
    LinkHub.FeatureFlags,
    LinkHub.Webhooks,
    LinkHub.Analytics
  ]

# Token signing secret — loaded from env var; fallback only for dev/test
config :link_hub,
  token_signing_secret:
    System.get_env("TOKEN_SIGNING_SECRET", "dev-only-not-for-production-at-least-32-bytes!!")

# Database
config :link_hub, LinkHub.Repo, migration_primary_key: [name: :id, type: :binary_id]

config :link_hub,
  ecto_repos: [LinkHub.Repo]

# Oban
config :link_hub, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, mailers: 20, billing: 5, ai: 3, media: 5],
  repo: LinkHub.Repo,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", LinkHub.Media.Workers.ExpiredLinkCleaner}
     ]}
  ]

# ExAws (S3 storage)
config :ex_aws,
  json_codec: Jason,
  normalize_path: false

config :ex_aws, :s3,
  scheme: "https://",
  region: "us-east-1"

# Stripe (keys loaded from runtime.exs)
config :stripity_stripe,
  api_version: "2024-04-10"

# Demo mode
config :link_hub, :demo_mode, System.get_env("DEMO_MODE") == "true"

# Import branding and plans config
import_config "branding.exs"
import_config "plans.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
