# priv/repo/ghanatrust_seeds.exs
# GhanaTrust compliance demo data. Idempotent — safe to run multiple times.
# Run with: mix run priv/repo/ghanatrust_seeds.exs

require Ash.Query

alias FounderPad.Accounts
alias FounderPad.ApiKeys.ApiKey
alias FounderPad.Compliance
alias FounderPad.Compliance.{IndividualVerification, Verifications}

IO.puts("🌿 Seeding GhanaTrust compliance demo...")

# --- Demo tenant + owner ---
owner =
  case Accounts.User |> Ash.Query.filter(email == "demo@ghanatrust.dev") |> Ash.read_one() do
    {:ok, %Accounts.User{} = u} ->
      u

    _ ->
      Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "demo@ghanatrust.dev",
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!()
  end

org =
  case Accounts.Organisation
       |> Ash.Query.filter(name == "GhanaTrust Demo Fintech")
       |> Ash.read_one() do
    {:ok, %Accounts.Organisation{} = o} ->
      o

    _ ->
      o =
        Accounts.Organisation
        |> Ash.Changeset.for_create(:create, %{name: "GhanaTrust Demo Fintech"})
        |> Ash.create!()

      Accounts.Membership
      |> Ash.Changeset.for_create(:create, %{
        role: :owner,
        user_id: owner.id,
        organisation_id: o.id
      })
      |> Ash.create!()

      o
  end

# --- Sandbox API key (raw key shown once) ---
existing_keys =
  ApiKey
  |> Ash.Query.filter(organisation_id == ^org.id and name == "Demo Sandbox Key")
  |> Ash.read!()

if existing_keys == [] do
  key =
    ApiKey
    |> Ash.Changeset.for_create(:create, %{
      name: "Demo Sandbox Key",
      scopes: [:read, :write],
      mode: :test,
      organisation_id: org.id,
      created_by_id: owner.id
    })
    |> Ash.create!()

  IO.puts("  🔑 Sandbox API key (save this — shown once): #{key.__raw_key__}")
else
  IO.puts("  🔑 Sandbox API key already exists (rotate via dashboard to see a raw value).")
end

# --- One of each sandbox outcome ---
for {card, ext} <- [
      {"GHA-TEST-VERIFIED-1", "demo_verified"},
      {"GHA-TEST-REVIEW-1", "demo_review"},
      {"GHA-TEST-FAILED-1", "demo_failed"}
    ] do
  already =
    IndividualVerification
    |> Ash.Query.filter(organisation_id == ^org.id and external_id == ^ext)
    |> Ash.read!()

  if already == [] do
    {:ok, ivf} =
      IndividualVerification
      |> Ash.Changeset.for_create(:create, %{
        organisation_id: org.id,
        external_id: ext,
        mode: :test,
        ghana_card_number: card,
        first_name: "Ama",
        last_name: "Mensah"
      })
      |> Ash.create()

    {:ok, processed} = Verifications.process(ivf, card)
    IO.puts("  ✓ #{ext}: #{processed.status} (risk: #{processed.risk_level})")
  end
end

open_cases = Compliance.list_open_review_cases!(org.id)
IO.puts("  📋 Open review cases: #{length(open_cases)}")
IO.puts("✅ GhanaTrust demo seeded for org #{org.id}")
