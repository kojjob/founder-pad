defmodule FounderPad.Compliance.LivenessTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  alias FounderPad.Compliance
  alias FounderPad.Compliance.{LivenessCheck, Verifications}
  alias FounderPad.Compliance.Providers.SandboxLiveness

  describe "SandboxLiveness.check" do
    test "passes a normal reference with high confidence" do
      {:ok, result} = SandboxLiveness.check(%{reference: "evidence/abc"})
      assert result.status == :passed
      assert result.confidence_score >= 0.9
    end

    test "fails a FAIL reference" do
      {:ok, result} = SandboxLiveness.check(%{reference: "LIVENESS-FAIL"})
      assert result.status == :failed
    end
  end

  describe "Verifications.run_liveness/2" do
    test "records a passed liveness check for the verification" do
      org = create_organisation!()
      ivf = create_individual_verification!(%{organisation: org})

      {:ok, check} = Verifications.run_liveness(ivf, "evidence/ok")

      assert check.status == :passed
      assert check.individual_verification_id == ivf.id
      assert check.provider_name == "sandbox"
      assert check.confidence_score
    end

    test "a failed liveness check opens a review case" do
      org = create_organisation!()
      ivf = create_individual_verification!(%{organisation: org})

      {:ok, check} = Verifications.run_liveness(ivf, "LIVENESS-FAIL")
      assert check.status == :failed

      cases = Compliance.list_open_review_cases!(org.id)
      assert Enum.any?(cases, &(&1.subject_id == ivf.id))
    end

    test "lists liveness checks for a verification" do
      org = create_organisation!()
      ivf = create_individual_verification!(%{organisation: org})
      {:ok, _} = Verifications.run_liveness(ivf, "evidence/ok")

      checks =
        LivenessCheck
        |> Ash.Query.for_read(:by_verification, %{individual_verification_id: ivf.id})
        |> Ash.read!()

      assert length(checks) == 1
    end
  end
end
