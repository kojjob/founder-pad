defmodule FounderPad.Compliance.IndividualVerificationTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  alias FounderPad.Compliance.IndividualVerification

  defp create_verification(attrs) do
    IndividualVerification
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  describe "create individual verification" do
    test "hashes the ghana card number and never stores the raw value" do
      org = create_organisation!()

      {:ok, ivf} =
        create_verification(%{
          organisation_id: org.id,
          external_id: "customer_1",
          mode: :test,
          ghana_card_number: "GHA-TEST-VERIFIED-1",
          first_name: "Ama",
          last_name: "Mensah",
          phone_number: "+233241234567"
        })

      assert ivf.status == :pending
      assert ivf.mode == :test
      assert ivf.ghana_card_number_hash == sha256("GHA-TEST-VERIFIED-1")
      assert ivf.phone_number_hash == sha256("+233241234567")
      # Raw value must not be persisted anywhere on the record
      refute Map.has_key?(ivf, :ghana_card_number)
    end

    test "in live mode requires an active consent receipt" do
      org = create_organisation!()

      {:error, error} =
        create_verification(%{
          organisation_id: org.id,
          external_id: "customer_2",
          mode: :live,
          ghana_card_number: "GHA-TEST-VERIFIED-1",
          first_name: "Ama",
          last_name: "Mensah"
        })

      assert Exception.message(error) =~ "consent"
    end

    test "in live mode succeeds with an active consent receipt" do
      org = create_organisation!()
      consent = create_consent_receipt!(%{organisation: org})

      {:ok, ivf} =
        create_verification(%{
          organisation_id: org.id,
          external_id: "customer_3",
          mode: :live,
          consent_receipt_id: consent.id,
          ghana_card_number: "GHA-TEST-VERIFIED-1",
          first_name: "Ama",
          last_name: "Mensah"
        })

      assert ivf.status == :pending
      assert ivf.consent_receipt_id == consent.id
    end

    test "in live mode rejects a withdrawn consent receipt" do
      org = create_organisation!()
      consent = create_consent_receipt!(%{organisation: org})
      {:ok, withdrawn} = consent |> Ash.Changeset.for_update(:withdraw, %{}) |> Ash.update()

      {:error, error} =
        create_verification(%{
          organisation_id: org.id,
          external_id: "customer_4",
          mode: :live,
          consent_receipt_id: withdrawn.id,
          ghana_card_number: "GHA-TEST-VERIFIED-1"
        })

      assert Exception.message(error) =~ "consent"
    end

    test "enforces external_id uniqueness per organisation" do
      org = create_organisation!()
      attrs = %{organisation_id: org.id, external_id: "dup", mode: :test, ghana_card_number: "X"}

      assert {:ok, _} = create_verification(attrs)
      assert {:error, error} = create_verification(attrs)
      assert Exception.message(error) =~ "already been taken"
    end
  end

  describe "apply_provider_result" do
    test "transitions to verified and records match level, reason codes and completion" do
      org = create_organisation!()

      {:ok, ivf} =
        create_verification(%{
          organisation_id: org.id,
          mode: :test,
          ghana_card_number: "GHA-TEST-VERIFIED-1"
        })

      {:ok, verified} =
        ivf
        |> Ash.Changeset.for_update(:apply_provider_result, %{
          status: :verified,
          identity_verified: true,
          match_level: :strong,
          reason_codes: ["identity_match"],
          provider_name: "sandbox",
          provider_reference: "sbx_abc"
        })
        |> Ash.update()

      assert verified.status == :verified
      assert verified.identity_verified == true
      assert verified.match_level == :strong
      assert verified.reason_codes == ["identity_match"]
      assert verified.completed_at
    end
  end

  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
