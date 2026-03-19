import Config

# White-label branding configuration
# Override these values to customize the app for different brands
config :founder_pad, :branding,
  app_name: "FounderPad",
  tagline: "Ship your SaaS faster",
  company_name: "FounderPad Inc.",
  support_email: "support@founderpad.io",
  marketing_url: "https://founderpad.io",
  logo_path: "/images/logo.svg",
  favicon_path: "/images/favicon.ico",
  primary_color: "#6366f1",
  accent_color: "#8083ff",
  # Social links
  twitter_url: nil,
  github_url: nil,
  discord_url: nil,
  # Feature flags (branding-level)
  show_powered_by: true,
  custom_domain_support: false
