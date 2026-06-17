defmodule FounderPad.Compliance.EvidenceItem do
  @moduledoc """
  Metadata for a piece of uploaded evidence (selfie, document, etc.).

  The bytes live in object storage; this record holds only the `storage_key` and
  metadata (content type, size, checksum, status, signed-URL expiry). `request_upload`
  presigns a one-time upload URL (returned transiently as `__upload_url__`, never
  persisted); the client uploads directly, then `mark_uploaded` records the result.
  """
  use Ash.Resource,
    domain: FounderPad.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias FounderPad.Compliance.Storage

  @types [:selfie, :document_front, :document_back, :proof_of_address, :business_document]
  @statuses [:pending_upload, :uploaded, :processed, :deleted]

  postgres do
    table("evidence_items")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :type, :atom do
      constraints(one_of: @types)
      allow_nil?(false)
      public?(true)
    end

    attribute :storage_key, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :content_type, :string do
      public?(true)
    end

    attribute :size_bytes, :integer do
      public?(true)
    end

    attribute :checksum, :string do
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: @statuses)
      default(:pending_upload)
      allow_nil?(false)
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

    belongs_to :individual_verification, FounderPad.Compliance.IndividualVerification do
      attribute_type(:uuid)
    end
  end

  actions do
    defaults([:read])

    create :request_upload do
      primary?(true)
      accept([:type, :content_type, :individual_verification_id, :organisation_id])
      change(&presign/2)
    end

    update :mark_uploaded do
      accept([:size_bytes, :checksum])
      change(set_attribute(:status, :uploaded))
    end

    update :mark_deleted do
      accept([])
      change(set_attribute(:status, :deleted))
    end

    read :by_verification do
      argument(:individual_verification_id, :uuid, allow_nil?: false)
      filter(expr(individual_verification_id == ^arg(:individual_verification_id)))
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

  defp presign(changeset, _context) do
    org_id = Ash.Changeset.get_attribute(changeset, :organisation_id)

    content_type =
      Ash.Changeset.get_attribute(changeset, :content_type) || "application/octet-stream"

    storage_key = "evidence/#{org_id}/#{Ash.UUID.generate()}"

    case Storage.presign_upload(storage_key, content_type) do
      {:ok, %{url: url, expires_at: expires_at}} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:storage_key, storage_key)
        |> Ash.Changeset.force_change_attribute(:expires_at, expires_at)
        |> Ash.Changeset.after_action(fn _changeset, item ->
          {:ok, Map.put(item, :__upload_url__, url)}
        end)

      {:error, reason} ->
        Ash.Changeset.add_error(changeset,
          field: :storage_key,
          message: "presign_failed: #{inspect(reason)}"
        )
    end
  end
end
