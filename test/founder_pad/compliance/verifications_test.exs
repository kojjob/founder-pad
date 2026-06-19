defmodule FounderPad.Compliance.VerificationsTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  alias FounderPad.Compliance.IndividualVerification
  alias FounderPad.Compliance.Verifications

  defp pending_verification(card) do
    org = create_organisation!()

    IndividualVerification
    |> Ash.Changeset.for_create(:create, %{
      organisation_id: org.id,
      mode: :test,
      ghana_card_number: card
    })
    |> Ash.create!()
  end

  describe "process/2" do
    test "a verified fixture becomes verified with low risk" do
      ivf = pending_verification("GHA-TEST-VERIFIED-1")

      {:ok, processed} = Verifications.process(ivf, "GHA-TEST-VERIFIED-1")

      assert processed.status == :verified
      assert processed.identity_verified == true
      assert processed.match_level == :strong
      assert processed.risk_level == :low
      assert processed.provider_name == "sandbox"
      assert processed.provider_reference =~ ~r/^sbx_/
      assert processed.completed_at
    end

    test "a review fixture is routed to requires_review with medium risk" do
      ivf = pending_verification("GHA-TEST-REVIEW-1")

      {:ok, processed} = Verifications.process(ivf, "GHA-TEST-REVIEW-1")

      assert processed.status == :requires_review
      assert processed.risk_level == :medium
    end

    test "a review outcome opens a review case for the subject" do
      ivf = pending_verification("GHA-TEST-REVIEW-1")

      {:ok, processed} = Verifications.process(ivf, "GHA-TEST-REVIEW-1")

      cases = FounderPad.Compliance.list_open_review_cases!(processed.organisation_id)
      assert [review] = cases
      assert review.subject_type == :individual_verification
      assert review.subject_id == processed.id
      assert review.status == :open
    end

    test "a verified outcome does not open a review case" do
      ivf = pending_verification("GHA-TEST-VERIFIED-1")
      {:ok, processed} = Verifications.process(ivf, "GHA-TEST-VERIFIED-1")
      assert FounderPad.Compliance.list_open_review_cases!(processed.organisation_id) == []
    end

    test "a failed fixture becomes failed with high risk" do
      ivf = pending_verification("GHA-TEST-FAILED-1")

      {:ok, processed} = Verifications.process(ivf, "GHA-TEST-FAILED-1")

      assert processed.status == :failed
      assert processed.identity_verified == false
      assert processed.risk_level == :high
    end

    test "a provider outage returns an error and leaves the check unfinished" do
      ivf = pending_verification("GHA-TEST-PROVIDER-DOWN")

      assert {:error, :provider_unavailable} =
               Verifications.process(ivf, "GHA-TEST-PROVIDER-DOWN")

      reloaded = Ash.get!(IndividualVerification, ivf.id)
      assert reloaded.status in [:pending, :processing]
      refute reloaded.completed_at
    end
  end
end
