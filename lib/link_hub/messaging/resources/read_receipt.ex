defmodule LinkHub.Messaging.ReadReceipt do
  @moduledoc "Ash resource representing a read receipt for a channel message."
  use Ash.Resource,
    domain: LinkHub.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("read_receipts")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :last_read_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
    end

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

    belongs_to :last_read_message, LinkHub.Messaging.Message do
      public?(true)
    end
  end

  identities do
    identity(:unique_receipt, [:channel_id, :user_id])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read])

    create :mark do
      accept([:last_read_at])
      upsert?(true)
      upsert_identity(:unique_receipt)
      upsert_fields([:last_read_at, :last_read_message_id])

      argument(:channel_id, :uuid, allow_nil?: false)
      argument(:user_id, :uuid, allow_nil?: false)
      argument(:last_read_message_id, :uuid)

      change(manage_relationship(:channel_id, :channel, type: :append))
      change(manage_relationship(:user_id, :user, type: :append))
      change(manage_relationship(:last_read_message_id, :last_read_message, type: :append))

      change(fn changeset, _ctx ->
        if Ash.Changeset.get_attribute(changeset, :last_read_at) do
          changeset
        else
          Ash.Changeset.change_attribute(changeset, :last_read_at, DateTime.utc_now())
        end
      end)
    end
  end
end
