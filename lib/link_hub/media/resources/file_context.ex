defmodule LinkHub.Media.FileContext do
  @moduledoc """
  Links StoredFile records to channels/messages for contextual display.
  A file can appear in multiple contexts (shared across channels).
  """
  use Ash.Resource,
    domain: LinkHub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("file_contexts")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :context_type, :atom do
      constraints(one_of: [:channel, :message, :direct_message])
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :stored_file, LinkHub.Media.StoredFile do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :channel, LinkHub.Messaging.Channel do
      public?(true)
    end

    belongs_to :message, LinkHub.Messaging.Message do
      public?(true)
    end
  end

  identities do
    identity(:unique_file_message, [:stored_file_id, :message_id])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:context_type])

      argument(:stored_file_id, :uuid, allow_nil?: false)
      argument(:channel_id, :uuid)
      argument(:message_id, :uuid)

      change(manage_relationship(:stored_file_id, :stored_file, type: :append))
      change(manage_relationship(:channel_id, :channel, type: :append))
      change(manage_relationship(:message_id, :message, type: :append))
    end

    read :list_by_message do
      argument(:message_id, :uuid, allow_nil?: false)
      filter(expr(message_id == ^arg(:message_id)))
      prepare(build(sort: [inserted_at: :asc], load: [:stored_file]))
    end

    read :list_by_channel do
      argument(:channel_id, :uuid, allow_nil?: false)
      filter(expr(channel_id == ^arg(:channel_id)))
      prepare(build(sort: [inserted_at: :desc], load: [:stored_file]))
    end
  end
end
