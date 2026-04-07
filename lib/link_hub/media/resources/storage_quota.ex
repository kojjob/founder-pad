defmodule LinkHub.Media.StorageQuota do
  @moduledoc """
  Tracks per-workspace storage usage against plan limits.

  One record per workspace. Updated atomically on upload/delete.
  A nil quota_bytes means unlimited storage (Enterprise plan).
  """
  use Ash.Resource,
    domain: LinkHub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("storage_quotas")
    repo(LinkHub.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :used_bytes, :integer do
      allow_nil?(false)
      default(0)
      constraints(min: 0)
      public?(true)
    end

    attribute :quota_bytes, :integer do
      public?(true)
    end

    attribute :file_count, :integer do
      allow_nil?(false)
      default(0)
      constraints(min: 0)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :workspace, LinkHub.Accounts.Workspace do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_workspace, [:workspace_id])
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:used_bytes, :quota_bytes, :file_count])
      argument(:workspace_id, :uuid, allow_nil?: false)
      change(manage_relationship(:workspace_id, :workspace, type: :append))
    end

    update :record_upload do
      accept([])
      argument(:file_size, :integer, allow_nil?: false)

      change(atomic_update(:used_bytes, expr(used_bytes + ^arg(:file_size))))
      change(atomic_update(:file_count, expr(file_count + 1)))
    end

    update :record_deletion do
      accept([])
      argument(:file_size, :integer, allow_nil?: false)

      change(
        atomic_update(
          :used_bytes,
          expr(if(used_bytes > ^arg(:file_size), used_bytes - ^arg(:file_size), 0))
        )
      )

      change(atomic_update(:file_count, expr(if(file_count > 1, file_count - 1, 0))))
    end

    update :set_quota do
      accept([:quota_bytes])
    end

    read :get_by_workspace do
      argument(:workspace_id, :uuid, allow_nil?: false)
      filter(expr(workspace_id == ^arg(:workspace_id)))
      prepare(build(limit: 1))
    end
  end

  calculations do
    calculate(
      :bytes_remaining,
      :integer,
      expr(
        if is_nil(quota_bytes) do
          nil
        else
          if quota_bytes > used_bytes do
            quota_bytes - used_bytes
          else
            0
          end
        end
      )
    )

    calculate(
      :usage_percentage,
      :integer,
      expr(if(is_nil(quota_bytes) or quota_bytes == 0, 0, used_bytes * 100 / quota_bytes))
    )
  end
end
