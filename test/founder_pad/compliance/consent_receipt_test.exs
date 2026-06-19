defmodule FounderPad.Compliance.ConsentReceiptTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  describe "create consent receipt" do
    test "records purpose, data categories and is active by default" do
      org = create_organisation!()

      {:ok, receipt} =
        FounderPad.Compliance.ConsentReceipt
        |> Ash.Changeset.for_create(:create, %{
          organisation_id: org.id,
          external_subject_id: "customer_123",
          purpose: "customer_onboarding",
          data_categories: [:identity, :biometric],
          channel: :web,
          privacy_notice_version: "2026-01",
          accepted_at: DateTime.utc_now(),
          ip_address: "41.66.0.1",
          user_agent: "Mozilla/5.0",
          retention_policy: "kyc_default"
        })
        |> Ash.create()

      assert receipt.status == :active
      assert receipt.purpose == "customer_onboarding"
      assert receipt.data_categories == [:identity, :biometric]
      assert receipt.channel == :web
      assert receipt.accepted_at
    end

    test "requires a purpose" do
      org = create_organisation!()

      {:error, error} =
        FounderPad.Compliance.ConsentReceipt
        |> Ash.Changeset.for_create(:create, %{
          organisation_id: org.id,
          channel: :web,
          accepted_at: DateTime.utc_now()
        })
        |> Ash.create()

      assert %Ash.Error.Invalid{} = error
    end
  end

  describe "withdraw consent receipt" do
    test "transitions status to withdrawn" do
      receipt = create_consent_receipt!()
      assert receipt.status == :active

      {:ok, withdrawn} =
        receipt
        |> Ash.Changeset.for_update(:withdraw, %{})
        |> Ash.update()

      assert withdrawn.status == :withdrawn
      assert withdrawn.withdrawn_at
    end
  end

  describe "consent fact immutability" do
    test "purpose cannot be changed after creation" do
      _receipt = create_consent_receipt!()

      # :withdraw is the only update action; no update action accepts :purpose
      accepted =
        FounderPad.Compliance.ConsentReceipt
        |> Ash.Resource.Info.action(:withdraw)
        |> Map.get(:accept, [])

      refute :purpose in accepted
    end
  end

  describe "active? for live processing" do
    test "an active, non-expired receipt is usable" do
      receipt = create_consent_receipt!()
      assert FounderPad.Compliance.ConsentReceipt.active?(receipt)
    end

    test "a withdrawn receipt is not usable" do
      receipt = create_consent_receipt!()
      {:ok, withdrawn} = receipt |> Ash.Changeset.for_update(:withdraw, %{}) |> Ash.update()
      refute FounderPad.Compliance.ConsentReceipt.active?(withdrawn)
    end
  end
end
