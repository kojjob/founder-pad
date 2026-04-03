# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :founder_pad,
  env: config_env(),
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :founder_pad, FounderPadWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FounderPadWeb.ErrorHTML, json: FounderPadWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: FounderPad.PubSub,
  live_view: [signing_salt: "MnhgwL4O"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :founder_pad, FounderPad.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  founder_pad: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  founder_pad: [
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
config :founder_pad,
  ash_domains: [FounderPad.Accounts, FounderPad.Billing, FounderPad.AI, FounderPad.Notifications, FounderPad.Audit, FounderPad.FeatureFlags, FounderPad.Webhooks, FounderPad.Analytics, FounderPad.Content, FounderPad.ApiKeys, FounderPad.HelpCenter, FounderPad.Privacy]

# Token signing secret — loaded from env var; fallback only for dev/test
config :founder_pad,
  token_signing_secret: System.get_env("TOKEN_SIGNING_SECRET", "dev-only-not-for-production-at-least-32-bytes!!")

# Database
config :founder_pad, FounderPad.Repo,
  migration_primary_key: [name: :id, type: :binary_id]

config :founder_pad,
  ecto_repos: [FounderPad.Repo]

# Oban
config :founder_pad, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, mailers: 20, billing: 5, ai: 3],
  repo: FounderPad.Repo,
  plugins: [
    {Oban.Plugins.Cron, crontab: [
      {"*/5 * * * *", FounderPad.Content.Workers.PublishScheduledPostsWorker}
    ]}
  ]

# Stripe (keys loaded from runtime.exs)
config :stripity_stripe,
  api_version: "2024-04-10"

# Demo mode
config :founder_pad, :demo_mode, System.get_env("DEMO_MODE") == "true"

# Import branding and plans config
import_config "branding.exs"
import_config "plans.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
