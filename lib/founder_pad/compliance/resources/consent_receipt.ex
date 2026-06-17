defmodule FounderPad.Compliance.ConsentReceipt do
  @moduledoc """
  An immutable record of a data subject's consent to process their personal data
  for a stated purpose.

  Consent must exist and be `:active` before any live identity processing runs
  (enforced by `FounderPad.Compliance.IndividualVerification`). The consent fact
  itself is immutable — only the lifecycle `status` may transition (active ->
  withdrawn/expired) via dedicated actions.
  """
  use Ash.Resource,
    domain: FounderPad.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @data_categories [:identity, :biometric, :contact, :business, :financial]
  @channels [:web, :mobile, :ussd, :sms, :api]
  @statuses [:active, :withdrawn, :expired]

  postgres do
    table("consent_receipts")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :external_subject_id, :string do
      public?(true)
    end

    attribute :purpose, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :data_categories, {:array, :atom} do
      constraints(items: [one_of: @data_categories])
      default([])
      allow_nil?(false)
      public?(true)
    end

    attribute :channel, :atom do
      constraints(one_of: @channels)
      default(:api)
      allow_nil?(false)
      public?(true)
    end

    attribute :privacy_notice_version, :string do
      public?(true)
    end

    attribute :accepted_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
    end

    attribute :ip_address, :string do
      public?(true)
    end

    attribute :user_agent, :string do
      public?(true)
    end

    attribute :device_fingerprint, :string do
      public?(true)
    end

    attribute :retention_policy, :string do
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: @statuses)
      default(:active)
      allow_nil?(false)
      public?(true)
    end

    attribute :withdrawn_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :expires_at, :utc_datetime_usec do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :organisation, FounderPad.Accounts.Organisation do
      allow_nil?(false)
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :external_subject_id,
        :purpose,
        :data_categories,
        :channel,
        :privacy_notice_version,
        :accepted_at,
        :ip_address,
        :user_agent,
        :device_fingerprint,
        :retention_policy,
        :expires_at,
        :organisation_id
      ])
    end

    update :withdraw do
      accept([])
      require_atomic?(false)
      change(set_attribute(:status, :withdrawn))
      change(set_attribute(:withdrawn_at, &DateTime.utc_now/0))
    end

    update :expire do
      accept([])
      require_atomic?(false)
      change(set_attribute(:status, :expired))
    end

    read :by_organisation do
      argument(:organisation_id, :uuid, allow_nil?: false)
      filter(expr(organisation_id == ^arg(:organisation_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if(always())
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if(always())
    end
  end

  @doc """
  Returns true when the receipt may be relied upon for live processing:
  it is `:active` and not past its `expires_at`.
  """
  def active?(%__MODULE__{status: :active, expires_at: nil}), do: true

  def active?(%__MODULE__{status: :active, expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :gt
  end

  def active?(%__MODULE__{}), do: false
end
