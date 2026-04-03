defmodule FounderPad.Privacy.DeletionRequest do
  use Ash.Resource,
    domain: FounderPad.Privacy,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "deletion_requests"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      constraints one_of: [:pending, :confirmed, :soft_deleted, :hard_deleted, :cancelled]
      default :pending
      allow_nil? false
      public? true
    end

    attribute :confirmation_token, :string do
      public? true
    end

    attribute :confirmed_at, :utc_datetime_usec do
      public? true
    end

    attribute :soft_deleted_at, :utc_datetime_usec do
      public? true
    end

    attribute :hard_delete_after, :utc_datetime_usec do
      public? true
    end

    attribute :hard_deleted_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, FounderPad.Accounts.User do
      allow_nil? false
      attribute_type :uuid
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:user_id]
      change fn changeset, _context ->
        token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
        Ash.Changeset.force_change_attribute(changeset, :confirmation_token, token)
      end
    end

    update :confirm do
      require_atomic? false
      change set_attribute(:status, :confirmed)
      change set_attribute(:confirmed_at, &DateTime.utc_now/0)
      change fn changeset, _context ->
        hard_delete_at = DateTime.add(DateTime.utc_now(), 30 * 86400, :second)
        Ash.Changeset.force_change_attribute(changeset, :hard_delete_after, hard_delete_at)
      end
    end

    update :execute_soft_delete do
      change set_attribute(:status, :soft_deleted)
      change set_attribute(:soft_deleted_at, &DateTime.utc_now/0)
    end

    update :cancel do
      change set_attribute(:status, :cancelled)
    end
  end
end
