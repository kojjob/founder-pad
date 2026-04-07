defmodule LinkHub.Messaging.ChannelMembership do
  @moduledoc "Ash resource representing a user's membership in a channel."
  use Ash.Resource,
    domain: LinkHub.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("channel_memberships")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    timestamps()
  end

  relationships do
    belongs_to :channel, LinkHub.Messaging.Channel do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :user, LinkHub.Accounts.User do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_user_per_channel, [:channel_id, :user_id])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :join do
      accept([])

      argument(:channel_id, :uuid, allow_nil?: false)
      argument(:user_id, :uuid, allow_nil?: false)

      change(manage_relationship(:channel_id, :channel, type: :append))
      change(manage_relationship(:user_id, :user, type: :append))
    end

    action :leave, :boolean do
      argument(:channel_id, :uuid, allow_nil?: false)
      argument(:user_id, :uuid, allow_nil?: false)

      run(fn input, _ctx ->
        import Ash.Query

        channel_id = input.arguments.channel_id
        user_id = input.arguments.user_id

        case __MODULE__
             |> filter(channel_id == ^channel_id and user_id == ^user_id)
             |> Ash.read_one!() do
          nil ->
            {:ok, false}

          membership ->
            Ash.destroy!(membership)
            {:ok, true}
        end
      end)
    end
  end
end
