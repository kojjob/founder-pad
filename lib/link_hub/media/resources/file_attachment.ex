defmodule LinkHub.Media.FileAttachment do
  @moduledoc "Ash resource representing an uploaded file attachment."
  use Ash.Resource,
    domain: LinkHub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("file_attachments")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :filename, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :content_type, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :size_bytes, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :storage_path, :string do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :workspace, LinkHub.Accounts.Workspace do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :uploader, LinkHub.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :message, LinkHub.Messaging.Message do
      public?(true)
    end
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:filename, :content_type, :size_bytes, :storage_path])

      argument(:workspace_id, :uuid, allow_nil?: false)
      argument(:uploader_id, :uuid, allow_nil?: false)
      argument(:message_id, :uuid)

      change(manage_relationship(:workspace_id, :workspace, type: :append))
      change(manage_relationship(:uploader_id, :uploader, type: :append))
      change(manage_relationship(:message_id, :message, type: :append))
    end

    read :list_by_message do
      argument(:message_id, :uuid, allow_nil?: false)

      filter(expr(message_id == ^arg(:message_id)))

      prepare(build(sort: [inserted_at: :asc]))
    end

    read :list_by_workspace do
      argument(:workspace_id, :uuid, allow_nil?: false)

      filter(expr(workspace_id == ^arg(:workspace_id)))

      prepare(build(sort: [inserted_at: :desc]))
    end

    read :search do
      argument(:workspace_id, :uuid, allow_nil?: false)
      argument(:query, :string, allow_nil?: false)

      filter(
        expr(
          workspace_id == ^arg(:workspace_id) and
            contains(filename, ^arg(:query))
        )
      )

      prepare(build(sort: [inserted_at: :desc]))
    end
  end

  calculations do
    calculate(:url, :string, expr("/uploads/" <> storage_path))

    calculate(:is_image, :boolean, expr(contains(content_type, "image/")))
  end
end
