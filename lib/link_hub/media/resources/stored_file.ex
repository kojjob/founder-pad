defmodule LinkHub.Media.StoredFile do
  @moduledoc """
  Ash resource representing a stored file with processing lifecycle.

  Replaces the simple FileAttachment with status tracking,
  content hashing, thumbnail support, and metadata storage.
  """
  use Ash.Resource,
    domain: LinkHub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("stored_files")
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
      constraints(min: 0)
      public?(true)
    end

    attribute :storage_key, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :processing, :ready, :failed])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :content_hash, :string do
      public?(true)
    end

    attribute :thumbnail_key, :string do
      public?(true)
    end

    attribute :metadata, :map do
      default(%{})
      allow_nil?(false)
      public?(true)
    end

    attribute :virus_scan_status, :atom do
      constraints(one_of: [:pending, :clean, :infected, :error])
      default(:pending)
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
  end

  identities do
    identity(:unique_storage_key, [:storage_key])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :upload do
      accept([:filename, :content_type, :size_bytes, :storage_key, :content_hash, :metadata])

      argument(:workspace_id, :uuid, allow_nil?: false)
      argument(:uploader_id, :uuid, allow_nil?: false)

      change(manage_relationship(:workspace_id, :workspace, type: :append))
      change(manage_relationship(:uploader_id, :uploader, type: :append))
    end

    update :mark_processing do
      accept([])
      change(set_attribute(:status, :processing))
    end

    update :mark_ready do
      accept([:thumbnail_key, :metadata])
      change(set_attribute(:status, :ready))
    end

    update :mark_failed do
      accept([:metadata])
      change(set_attribute(:status, :failed))
    end

    update :set_virus_scan do
      accept([])

      argument(:scan_result, :atom,
        allow_nil?: false,
        constraints: [one_of: [:clean, :infected, :error]]
      )

      change(set_attribute(:virus_scan_status, arg(:scan_result)))
    end

    read :list_by_workspace do
      argument(:workspace_id, :uuid, allow_nil?: false)
      filter(expr(workspace_id == ^arg(:workspace_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :list_ready_by_workspace do
      argument(:workspace_id, :uuid, allow_nil?: false)
      filter(expr(workspace_id == ^arg(:workspace_id) and status == :ready))
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
    calculate(:is_image, :boolean, expr(contains(content_type, "image/")))
  end
end
