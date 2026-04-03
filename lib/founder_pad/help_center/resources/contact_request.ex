defmodule FounderPad.HelpCenter.ContactRequest do
  use Ash.Resource,
    domain: FounderPad.HelpCenter,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "help_contact_requests"
    repo FounderPad.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    attribute :subject, :string do
      allow_nil? false
      public? true
    end

    attribute :message, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:new, :in_progress, :resolved]
      default :new
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :email, :subject, :message]
    end

    update :update_status do
      accept [:status]
    end
  end
end
