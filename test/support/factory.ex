defmodule FounderPad.Factory do
  @moduledoc "Test factories for FounderPad resources."

  def unique_email, do: "user_#{System.unique_integer([:positive])}@example.com"

  def build_user(attrs \\ %{}) do
    default = %{
      email: unique_email(),
      hashed_password: Bcrypt.hash_pwd_salt("Password123!"),
      name: "Test User"
    }

    Map.merge(default, Map.new(attrs))
  end

  def create_user!(attrs \\ %{}) do
    FounderPad.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: attrs[:email] || unique_email(),
      password: attrs[:password] || "Password123!",
      password_confirmation: attrs[:password_confirmation] || attrs[:password] || "Password123!"
    })
    |> Ash.create!()
  end

  def build_organisation(attrs \\ %{}) do
    default = %{
      name: "Test Org #{System.unique_integer([:positive])}"
    }

    Map.merge(default, Map.new(attrs))
  end

  def create_admin_user!(attrs \\ %{}) do
    user = create_user!(attrs)

    user
    |> Ash.Changeset.for_update(:update_profile, %{})
    |> Ash.Changeset.force_change_attribute(:is_admin, true)
    |> Ash.update!()
  end

  def create_organisation!(attrs \\ %{}) do
    params = build_organisation(attrs)

    FounderPad.Accounts.Organisation
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_membership!(user, org, role \\ :member) do
    FounderPad.Accounts.Membership
    |> Ash.Changeset.for_create(:create, %{role: role, user_id: user.id, organisation_id: org.id})
    |> Ash.create!()
  end

  def create_plan!(attrs \\ %{}) do
    default = %{
      name: "Test Plan #{System.unique_integer([:positive])}",
      slug: "test-plan-#{System.unique_integer([:positive])}",
      stripe_product_id: "prod_test_#{System.unique_integer([:positive])}",
      stripe_price_id: "price_test_#{System.unique_integer([:positive])}",
      price_cents: 2900,
      interval: :monthly,
      features: ["Feature A"],
      max_seats: 5,
      max_agents: 10,
      max_api_calls_per_month: 10_000
    }

    params = Map.merge(default, Map.new(attrs))

    FounderPad.Billing.Plan
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_agent!(org, attrs \\ %{}) do
    default = %{
      name: "Test Agent #{System.unique_integer([:positive])}",
      system_prompt: "You are a helpful test assistant.",
      model: "claude-sonnet-4-20250514",
      provider: :anthropic,
      organisation_id: org.id
    }

    params = Map.merge(default, Map.new(attrs))

    FounderPad.AI.Agent
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_invoice!(org, attrs \\ %{}) do
    default = %{
      invoice_number: "INV-#{System.unique_integer([:positive])}",
      amount_cents: 14900,
      status: :paid,
      period_start: Date.utc_today() |> Date.beginning_of_month(),
      period_end: Date.utc_today() |> Date.end_of_month(),
      organisation_id: org.id
    }

    FounderPad.Billing.Invoice
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!()
  end

  def create_conversation_chain! do
    org = create_organisation!()
    user = create_user!()
    agent = create_agent!(org)

    {:ok, conversation} =
      FounderPad.AI.Conversation
      |> Ash.Changeset.for_create(:create, %{
        title: "Test Conversation",
        agent_id: agent.id,
        organisation_id: org.id,
        user_id: user.id
      })
      |> Ash.create()

    {org, user, agent, conversation}
  end
end
