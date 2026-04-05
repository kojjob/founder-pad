defmodule FounderPad.Privacy.DataExportRequest do
  use Ash.Resource,
    domain: FounderPad.Privacy,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("data_export_requests")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :status, :atom do
      constraints(one_of: [:pending, :processing, :completed, :failed, :expired])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :file_path, :string do
      public?(true)
    end

    attribute :expires_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :completed_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :error, :string do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :user, FounderPad.Accounts.User do
      allow_nil?(false)
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:user_id])
    end

    update :mark_completed do
      require_atomic?(false)
      accept([:file_path])
      change(set_attribute(:status, :completed))
      change(set_attribute(:completed_at, &DateTime.utc_now/0))

      change(fn changeset, _context ->
        expires = DateTime.add(DateTime.utc_now(), 48 * 3600, :second)
        Ash.Changeset.force_change_attribute(changeset, :expires_at, expires)
      end)
    end

    update :mark_failed do
      accept([:error])
      change(set_attribute(:status, :failed))
    end

    read :by_user do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
