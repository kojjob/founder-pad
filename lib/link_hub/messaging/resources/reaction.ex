defmodule LinkHub.Messaging.Reaction do
  @moduledoc "Ash resource representing an emoji reaction on a message."
  use Ash.Resource,
    domain: LinkHub.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("reactions")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :emoji, :string do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :message, LinkHub.Messaging.Message do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :user, LinkHub.Accounts.User do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_reaction, [:message_id, :user_id, :emoji])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :add do
      accept([:emoji])

      argument(:message_id, :uuid, allow_nil?: false)
      argument(:user_id, :uuid, allow_nil?: false)

      change(manage_relationship(:message_id, :message, type: :append))
      change(manage_relationship(:user_id, :user, type: :append))
    end

    action :remove, :boolean do
      argument(:message_id, :uuid, allow_nil?: false)
      argument(:user_id, :uuid, allow_nil?: false)
      argument(:emoji, :string, allow_nil?: false)

      run(fn input, _ctx ->
        import Ash.Query

        message_id = input.arguments.message_id
        user_id = input.arguments.user_id
        emoji_val = input.arguments.emoji

        case __MODULE__
             |> filter(message_id == ^message_id and user_id == ^user_id and emoji == ^emoji_val)
             |> Ash.read_one!() do
          nil ->
            {:ok, false}

          reaction ->
            Ash.destroy!(reaction)
            {:ok, true}
        end
      end)
    end
  end
end
