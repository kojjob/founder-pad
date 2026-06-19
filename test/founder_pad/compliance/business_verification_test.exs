defmodule FounderPad.Compliance.BusinessVerificationTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  alias FounderPad.Compliance
  alias FounderPad.Compliance.{BusinessVerification, KybVerifications}
  alias FounderPad.Compliance.Providers.SandboxKyb

  defp sha256(v), do: :crypto.hash(:sha256, v) |> Base.encode16(case: :lower)

  defp create_bv(attrs) do
    BusinessVerification
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  describe "SandboxKyb.verify" do
    test "CS-TEST-VERIFIED-1 verifies with low risk" do
      {:ok, result} = SandboxKyb.verify(%{registration_number: "CS-TEST-VERIFIED-1"})
      assert result.status == :verified
      assert result.risk_level == :low
    end

    test "CS-TEST-REVIEW-1 needs review; CS-TEST-FAILED-1 fails; PROVIDER-DOWN errors" do
      assert {:ok, %{status: :requires_review}} =
               SandboxKyb.verify(%{registration_number: "CS-TEST-REVIEW-1"})

      assert {:ok, %{status: :failed, risk_level: :high}} =
               SandboxKyb.verify(%{registration_number: "CS-TEST-FAILED-1"})

      assert {:error, :provider_unavailable} =
               SandboxKyb.verify(%{registration_number: "CS-TEST-PROVIDER-DOWN"})
    end
  end

  describe "create business verification" do
    test "hashes registration number and TIN, never storing raw values" do
      org = create_organisation!()

      {:ok, bv} =
        create_bv(%{
          organisation_id: org.id,
          external_id: "merchant_1",
          mode: :test,
          registered_name: "Example Trading Ltd",
          registration_number: "CS-TEST-VERIFIED-1",
          tin: "P0001234567"
        })

      assert bv.status == :pending
      assert bv.registered_name == "Example Trading Ltd"
      assert bv.registration_number_hash == sha256("CS-TEST-VERIFIED-1")
      assert bv.tin_hash == sha256("P0001234567")
      refute Map.has_key?(bv, :registration_number)
    end

    test "enforces external_id uniqueness per organisation" do
      org = create_organisation!()

      attrs = %{
        organisation_id: org.id,
        external_id: "dup",
        mode: :test,
        registration_number: "X"
      }

      assert {:ok, _} = create_bv(attrs)
      assert {:error, error} = create_bv(attrs)
      assert Exception.message(error) =~ "already been taken"
    end
  end

  describe "KybVerifications.process/2" do
    test "a verified business becomes verified with low risk" do
      org = create_organisation!()

      {:ok, bv} =
        create_bv(%{
          organisation_id: org.id,
          mode: :test,
          registration_number: "CS-TEST-VERIFIED-1"
        })

      {:ok, processed} = KybVerifications.process(bv, "CS-TEST-VERIFIED-1")

      assert processed.status == :verified
      assert processed.risk_level == :low
      assert processed.provider_name == "sandbox"
      assert processed.completed_at
    end

    test "a review business opens a review case" do
      org = create_organisation!()

      {:ok, bv} =
        create_bv(%{
          organisation_id: org.id,
          mode: :test,
          registration_number: "CS-TEST-REVIEW-1"
        })

      {:ok, processed} = KybVerifications.process(bv, "CS-TEST-REVIEW-1")
      assert processed.status == :requires_review

      cases = Compliance.list_open_review_cases!(org.id)

      assert Enum.any?(
               cases,
               &(&1.subject_type == :business_verification and &1.subject_id == bv.id)
             )
    end

    test "a provider outage leaves the check unfinished" do
      org = create_organisation!()

      {:ok, bv} =
        create_bv(%{
          organisation_id: org.id,
          mode: :test,
          registration_number: "CS-TEST-PROVIDER-DOWN"
        })

      assert {:error, :provider_unavailable} =
               KybVerifications.process(bv, "CS-TEST-PROVIDER-DOWN")

      reloaded = Ash.get!(BusinessVerification, bv.id)
      refute reloaded.completed_at
    end
  end
end
