defmodule FounderPad.Compliance.EvidenceTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  alias FounderPad.Compliance.{EvidenceItem, Storage}

  describe "Storage.Sandbox presign" do
    test "returns a future-dated upload URL referencing the key" do
      {:ok, presigned} = Storage.presign_upload("evidence/org/abc", "image/jpeg")

      assert presigned.url =~ "evidence/org/abc"
      assert DateTime.compare(presigned.expires_at, DateTime.utc_now()) == :gt
    end
  end

  describe "request_upload" do
    test "creates a pending evidence item with a storage key and a one-time upload URL" do
      org = create_organisation!()

      {:ok, item} =
        EvidenceItem
        |> Ash.Changeset.for_create(:request_upload, %{
          organisation_id: org.id,
          type: :selfie,
          content_type: "image/jpeg"
        })
        |> Ash.create()

      assert item.status == :pending_upload
      assert item.type == :selfie
      assert item.storage_key =~ "evidence/#{org.id}/"
      assert item.expires_at
      assert item.__upload_url__ =~ item.storage_key
      # The raw image is never stored on the record — only metadata.
      refute Map.has_key?(item, :data)
    end
  end

  describe "mark_uploaded" do
    test "records checksum and size and flips status to uploaded" do
      org = create_organisation!()

      {:ok, item} =
        EvidenceItem
        |> Ash.Changeset.for_create(:request_upload, %{
          organisation_id: org.id,
          type: :selfie,
          content_type: "image/jpeg"
        })
        |> Ash.create()

      {:ok, uploaded} =
        item
        |> Ash.Changeset.for_update(:mark_uploaded, %{
          size_bytes: 20_481,
          checksum: "sha256:abc"
        })
        |> Ash.update()

      assert uploaded.status == :uploaded
      assert uploaded.size_bytes == 20_481
      assert uploaded.checksum == "sha256:abc"
    end
  end
end
