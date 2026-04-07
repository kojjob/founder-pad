import Config

config :link_hub, :plans, [
  %{
    name: "Free",
    slug: "free",
    stripe_product_id: "prod_free",
    stripe_price_id: "price_free",
    price_cents: 0,
    interval: :monthly,
    features: [
      "Up to 10 members",
      "Basic channels & threads",
      "5GB file storage",
      "Community support"
    ],
    max_seats: 10,
    max_file_size_bytes: 20_000_000,
    max_storage_bytes: 5_368_709_120,
    sort_order: 0
  },
  %{
    name: "Pro",
    slug: "pro",
    stripe_product_id: "prod_pro",
    stripe_price_id: "price_pro_monthly",
    price_cents: 800,
    interval: :monthly,
    features: [
      "Unlimited members",
      "Video huddles",
      "100GB file storage",
      "Priority support",
      "Advanced search",
      "Custom integrations",
      "Collaborative whiteboards"
    ],
    max_seats: nil,
    max_file_size_bytes: 104_857_600,
    max_storage_bytes: 107_374_182_400,
    sort_order: 1
  },
  %{
    name: "Enterprise",
    slug: "enterprise",
    stripe_product_id: "prod_enterprise",
    stripe_price_id: "price_enterprise_monthly",
    price_cents: nil,
    interval: :monthly,
    features: [
      "Everything in Pro",
      "SSO/SAML",
      "Audit logs",
      "99.99% SLA",
      "Dedicated support",
      "Unlimited storage",
      "Custom data retention"
    ],
    max_seats: nil,
    max_file_size_bytes: nil,
    max_storage_bytes: nil,
    sort_order: 2
  }
]
