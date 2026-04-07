defmodule LinkHub.Messaging.Message do
  @moduledoc "Ash resource representing a message in a channel."
  use Ash.Resource,
    domain: LinkHub.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [LinkHub.Messaging.Notifiers.MessageNotifier]

  postgres do
    table("messages")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute(:edited_at, :utc_datetime_usec, public?: true)
    attribute(:deleted_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :channel, LinkHub.Messaging.Channel do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :author, LinkHub.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :parent_message, LinkHub.Messaging.Message do
      public?(true)
    end

    has_many :replies, LinkHub.Messaging.Message do
      destination_attribute(:parent_message_id)
    end

    has_many(:reactions, LinkHub.Messaging.Reaction)
    has_many(:attachments, LinkHub.Media.FileAttachment)
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read])

    create :send do
      accept([:body, :channel_id, :parent_message_id])

      argument(:author_id, :uuid, allow_nil?: false)

      change(manage_relationship(:author_id, :author, type: :append))
    end

    read :list_by_channel do
      argument(:channel_id, :uuid, allow_nil?: false)

      filter(expr(channel_id == ^arg(:channel_id) and is_nil(deleted_at)))

      prepare(build(sort: [inserted_at: :asc], load: [:author, :reactions]))
    end

    read :list_thread do
      argument(:parent_message_id, :uuid, allow_nil?: false)

      filter(expr(parent_message_id == ^arg(:parent_message_id) and is_nil(deleted_at)))

      prepare(build(sort: [inserted_at: :asc], load: [:author, :reactions]))
    end

    read :search do
      argument(:channel_id, :uuid, allow_nil?: false)
      argument(:query, :string, allow_nil?: false)

      filter(
        expr(
          channel_id == ^arg(:channel_id) and
            is_nil(deleted_at) and
            contains(body, ^arg(:query))
        )
      )

      prepare(build(sort: [inserted_at: :desc], load: [:author]))
    end

    update :edit do
      accept([:body])

      change(set_attribute(:edited_at, &DateTime.utc_now/0))
    end

    update :soft_delete do
      change(set_attribute(:deleted_at, &DateTime.utc_now/0))
      change(set_attribute(:body, "[deleted]"))
    end
  end

  aggregates do
    count :reply_count, :replies do
      filter(expr(is_nil(deleted_at)))
    end
  end
end
