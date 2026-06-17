defmodule FounderPad.Compliance.ReviewNote do
  @moduledoc "A timestamped note left by a reviewer on a review case."
  use Ash.Resource,
    domain: FounderPad.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("review_notes")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
  end

  relationships do
    belongs_to :review_case, FounderPad.Compliance.ReviewCase do
      allow_nil?(false)
      attribute_type(:uuid)
    end

    belongs_to :user, FounderPad.Accounts.User do
      allow_nil?(false)
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:body, :review_case_id, :user_id])
    end

    read :by_case do
      argument(:review_case_id, :uuid, allow_nil?: false)
      filter(expr(review_case_id == ^arg(:review_case_id)))
      prepare(build(sort: [inserted_at: :asc]))
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
end
