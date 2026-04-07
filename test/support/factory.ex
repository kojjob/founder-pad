defmodule LinkHub.Factory do
  @moduledoc "Test factories for LinkHub resources."

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
    LinkHub.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: attrs[:email] || unique_email(),
      password: attrs[:password] || "Password123!",
      password_confirmation: attrs[:password_confirmation] || attrs[:password] || "Password123!"
    })
    |> Ash.create!()
  end

  def build_workspace(attrs \\ %{}) do
    default = %{
      name: "Test Org #{System.unique_integer([:positive])}"
    }

    Map.merge(default, Map.new(attrs))
  end

  def create_workspace!(attrs \\ %{}) do
    params = build_workspace(attrs)

    LinkHub.Accounts.Workspace
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_membership!(user, org, role \\ :member) do
    LinkHub.Accounts.Membership
    |> Ash.Changeset.for_create(:create, %{role: role, user_id: user.id, workspace_id: org.id})
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
      max_api_calls_per_month: 10_000,
      max_file_size_bytes: 20_000_000,
      max_storage_bytes: 5_368_709_120
    }

    params = Map.merge(default, Map.new(attrs))

    LinkHub.Billing.Plan
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_agent!(org, attrs \\ %{}) do
    default = %{
      name: "Test Agent #{System.unique_integer([:positive])}",
      system_prompt: "You are a helpful test assistant.",
      model: "claude-sonnet-4-20250514",
      provider: :anthropic,
      workspace_id: org.id
    }

    params = Map.merge(default, Map.new(attrs))

    LinkHub.AI.Agent
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_invoice!(org, attrs \\ %{}) do
    default = %{
      invoice_number: "INV-#{System.unique_integer([:positive])}",
      amount_cents: 14_900,
      status: :paid,
      period_start: Date.utc_today() |> Date.beginning_of_month(),
      period_end: Date.utc_today() |> Date.end_of_month(),
      workspace_id: org.id
    }

    LinkHub.Billing.Invoice
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!()
  end

  # ── Messaging factories ──

  def create_channel!(workspace, user, attrs \\ %{}) do
    default = %{
      name: "test-channel-#{System.unique_integer([:positive])}",
      visibility: :public,
      workspace_id: workspace.id,
      created_by_id: user.id
    }

    params = Map.merge(default, Map.new(attrs))

    LinkHub.Messaging.Channel
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def join_channel!(channel, user) do
    LinkHub.Messaging.ChannelMembership
    |> Ash.Changeset.for_create(:join, %{channel_id: channel.id, user_id: user.id})
    |> Ash.create!()
  end

  def send_message!(channel, user, body, opts \\ %{}) do
    params =
      Map.merge(
        %{body: body, channel_id: channel.id, author_id: user.id},
        Map.new(opts)
      )

    LinkHub.Messaging.Message
    |> Ash.Changeset.for_create(:send, params)
    |> Ash.create!()
  end

  def add_reaction!(message, user, emoji) do
    LinkHub.Messaging.Reaction
    |> Ash.Changeset.for_create(:add, %{emoji: emoji, message_id: message.id, user_id: user.id})
    |> Ash.create!()
  end

  def create_messaging_context! do
    workspace = create_workspace!()
    user = create_user!()
    create_membership!(user, workspace)
    channel = create_channel!(workspace, user)
    join_channel!(channel, user)
    {workspace, user, channel}
  end

  # ── Media factories ──

  def create_stored_file!(workspace, user, attrs \\ %{}) do
    default = %{
      filename: "test-file-#{System.unique_integer([:positive])}.png",
      content_type: "image/png",
      size_bytes: 1_048_576,
      storage_key: "uploads/#{Ash.UUID.generate()}.png",
      workspace_id: workspace.id,
      uploader_id: user.id
    }

    params = Map.merge(default, Map.new(attrs))

    LinkHub.Media.StoredFile
    |> Ash.Changeset.for_create(:upload, params)
    |> Ash.create!()
  end

  # ── AI factories ──

  def create_conversation_chain! do
    org = create_workspace!()
    user = create_user!()
    agent = create_agent!(org)

    {:ok, conversation} =
      LinkHub.AI.Conversation
      |> Ash.Changeset.for_create(:create, %{
        title: "Test Conversation",
        agent_id: agent.id,
        workspace_id: org.id,
        user_id: user.id
      })
      |> Ash.create()

    {org, user, agent, conversation}
  end
end
