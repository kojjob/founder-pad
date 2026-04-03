defmodule FounderPad.Privacy.PrivacyTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  describe "cookie consent" do
    test "creates consent record" do
      {:ok, consent} =
        FounderPad.Privacy.CookieConsent
        |> Ash.Changeset.for_create(:create, %{
          consent_id: "test-123",
          analytics: true,
          marketing: false,
          ip_address: "127.0.0.1"
        })
        |> Ash.create()

      assert consent.consent_id == "test-123"
      assert consent.analytics == true
      assert consent.marketing == false
      assert consent.functional == true
    end
  end

  describe "data export request" do
    test "creates and completes export request" do
      user = create_user!()

      {:ok, request} =
        FounderPad.Privacy.DataExportRequest
        |> Ash.Changeset.for_create(:create, %{user_id: user.id})
        |> Ash.create()

      assert request.status == :pending

      {:ok, completed} =
        request
        |> Ash.Changeset.for_update(:mark_completed, %{file_path: "/exports/user_data.zip"})
        |> Ash.update()

      assert completed.status == :completed
      assert completed.file_path == "/exports/user_data.zip"
      assert completed.expires_at
    end
  end

  describe "deletion request" do
    test "creates with confirmation token and confirms" do
      user = create_user!()

      {:ok, request} =
        FounderPad.Privacy.DeletionRequest
        |> Ash.Changeset.for_create(:create, %{user_id: user.id})
        |> Ash.create()

      assert request.status == :pending
      assert request.confirmation_token

      {:ok, confirmed} =
        request
        |> Ash.Changeset.for_update(:confirm, %{})
        |> Ash.update()

      assert confirmed.status == :confirmed
      assert confirmed.confirmed_at
      assert confirmed.hard_delete_after
    end

    test "can cancel deletion" do
      user = create_user!()

      {:ok, request} =
        FounderPad.Privacy.DeletionRequest
        |> Ash.Changeset.for_create(:create, %{user_id: user.id})
        |> Ash.create()

      {:ok, cancelled} =
        request
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update()

      assert cancelled.status == :cancelled
    end
  end
end
