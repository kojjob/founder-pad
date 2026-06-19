defmodule FounderPad.Compliance.Providers.SandboxTest do
  use ExUnit.Case, async: true

  alias FounderPad.Compliance.Providers.Sandbox

  defp input(card), do: %{ghana_card_number: card, first_name: "Ama", last_name: "Mensah"}

  describe "deterministic fixtures" do
    test "GHA-TEST-VERIFIED-1 returns a strong verified match" do
      assert {:ok, result} = Sandbox.verify(input("GHA-TEST-VERIFIED-1"))
      assert result.status == :verified
      assert result.identity_verified == true
      assert result.match_level == :strong
      assert "identity_match" in result.reason_codes
    end

    test "GHA-TEST-FAILED-1 returns a failed result with no match" do
      assert {:ok, result} = Sandbox.verify(input("GHA-TEST-FAILED-1"))
      assert result.status == :failed
      assert result.identity_verified == false
      assert result.match_level == :none
    end

    test "GHA-TEST-REVIEW-1 returns requires_review" do
      assert {:ok, result} = Sandbox.verify(input("GHA-TEST-REVIEW-1"))
      assert result.status == :requires_review
    end

    test "GHA-TEST-PROVIDER-DOWN simulates an unavailable provider" do
      assert {:error, :provider_unavailable} = Sandbox.verify(input("GHA-TEST-PROVIDER-DOWN"))
    end
  end

  describe "provider_reference" do
    test "is stable for the same card number" do
      {:ok, a} = Sandbox.verify(input("GHA-TEST-VERIFIED-1"))
      {:ok, b} = Sandbox.verify(input("GHA-TEST-VERIFIED-1"))
      assert a.provider_reference == b.provider_reference
      assert a.provider_reference =~ ~r/^sbx_/
    end
  end

  describe "default behaviour" do
    test "an unknown well-formed card defaults to a deterministic verified result" do
      assert {:ok, result} = Sandbox.verify(input("GHA-000000000-0"))
      assert result.status in [:verified, :requires_review]
      assert result.provider_name == "sandbox"
    end
  end

  describe "behaviour contract" do
    test "Sandbox implements the IdentityProvider behaviour" do
      behaviours =
        Sandbox.module_info(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()

      assert FounderPad.Compliance.Providers.IdentityProvider in behaviours
    end
  end
end
