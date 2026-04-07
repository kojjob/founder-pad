defmodule FounderPad.Referrals.Referral do
  use Ash.Resource,
    domain: FounderPad.Referrals,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("referrals")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:code, :string, allow_nil?: false, public?: true)

    attribute(:status, :atom,
      constraints: [one_of: [:pending, :completed, :expired]],
      default: :pending,
      public?: true
    )

    attribute(:reward_type, :string, default: "credit", public?: true)
    attribute(:reward_amount_cents, :integer, default: 500, public?: true)
    attribute(:completed_at, :utc_datetime_usec, public?: true)
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to(:referrer, FounderPad.Accounts.User, allow_nil?: false, attribute_type: :uuid)
    belongs_to(:referred, FounderPad.Accounts.User, attribute_type: :uuid)
  end

  identities do
    identity(:unique_code, [:code])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:referrer_id])

      change(fn changeset, _ ->
        code = "FP-" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper))
        Ash.Changeset.force_change_attribute(changeset, :code, code)
      end)
    end

    update :complete do
      accept([:referred_id])
      change(set_attribute(:status, :completed))
      change(set_attribute(:completed_at, &DateTime.utc_now/0))
    end

    read :by_code do
      argument(:code, :string, allow_nil?: false)
      filter(expr(code == ^arg(:code) and status == :pending))
    end

    read :by_referrer do
      argument(:referrer_id, :uuid, allow_nil?: false)
      filter(expr(referrer_id == ^arg(:referrer_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
