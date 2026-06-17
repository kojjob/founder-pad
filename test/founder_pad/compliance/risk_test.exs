defmodule FounderPad.Compliance.RiskTest do
  use ExUnit.Case, async: true

  alias FounderPad.Compliance.Risk

  defp provider_result(status, match_level, verified?) do
    %{
      status: status,
      identity_verified: verified?,
      match_level: match_level,
      reason_codes: [],
      provider_name: "sandbox",
      provider_reference: "sbx_x"
    }
  end

  describe "assess/1 (rules_v1)" do
    test "a strong verified identity is low risk" do
      assessment = Risk.assess(provider_result(:verified, :strong, true))
      assert assessment.level == :low
      assert assessment.score <= 30
      assert assessment.model_version == "rules_v1"
    end

    test "a provider review outcome is medium risk" do
      assessment = Risk.assess(provider_result(:requires_review, :medium, false))
      assert assessment.level == :medium
    end

    test "a failed identity is high risk" do
      assessment = Risk.assess(provider_result(:failed, :none, false))
      assert assessment.level == :high
      assert assessment.score >= 70
    end

    test "a verified-but-weak match is escalated to medium risk" do
      assessment = Risk.assess(provider_result(:verified, :weak, true))
      assert assessment.level == :medium
    end

    test "carries through provider reason codes" do
      result = %{provider_result(:verified, :strong, true) | reason_codes: ["identity_match"]}
      assessment = Risk.assess(result)
      assert "identity_match" in assessment.reason_codes
    end
  end

  describe "final_status/2" do
    test "a verified strong match with low risk stays verified" do
      assert Risk.final_status(:verified, :low) == :verified
    end

    test "a verified match with medium risk is escalated to review" do
      assert Risk.final_status(:verified, :medium) == :requires_review
    end

    test "a failed provider result stays failed regardless of risk" do
      assert Risk.final_status(:failed, :high) == :failed
    end
  end
end
