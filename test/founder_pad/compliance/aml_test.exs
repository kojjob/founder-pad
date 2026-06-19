defmodule FounderPad.Compliance.AmlTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  alias FounderPad.Compliance
  alias FounderPad.Compliance.{AmlScreen, AmlScreening, Risk}
  alias FounderPad.Compliance.Providers.SandboxAml

  describe "SandboxAml.screen" do
    test "a clear name returns clear with no matches" do
      {:ok, result} = SandboxAml.screen(%{name: "Ama Mensah", subject_type: :person})
      assert result.status == :clear
      assert result.match_count == 0
    end

    test "a PEP name returns a possible_match, never auto-confirmed" do
      {:ok, result} = SandboxAml.screen(%{name: "AML-PEP Person", subject_type: :person})
      assert result.status == :possible_match
      assert "pep" in result.lists_checked
    end

    test "even a sanctions hit is only a possible_match (human must confirm)" do
      {:ok, result} = SandboxAml.screen(%{name: "AML-SANCTION Co", subject_type: :business})
      assert result.status == :possible_match
      refute result.status == :confirmed_match
    end

    test "a provider outage errors" do
      assert {:error, :provider_unavailable} =
               SandboxAml.screen(%{name: "AML-DOWN", subject_type: :person})
    end
  end

  describe "AmlScreening.screen/4" do
    test "records a clear screen without opening a review case" do
      org = create_organisation!()
      subject_id = Ash.UUID.generate()

      {:ok, screen} = AmlScreening.screen(org.id, :person, subject_id, "Ama Mensah")

      assert screen.status == :clear
      assert Compliance.list_open_review_cases!(org.id) == []
    end

    test "a possible match opens an aml_screen review case" do
      org = create_organisation!()
      subject_id = Ash.UUID.generate()

      {:ok, screen} = AmlScreening.screen(org.id, :person, subject_id, "AML-PEP Person")
      assert screen.status == :possible_match

      cases = Compliance.list_open_review_cases!(org.id)
      assert Enum.any?(cases, &(&1.subject_type == :aml_screen and &1.subject_id == screen.id))
    end
  end

  describe "Risk.combine_aml/2 (rules_v2)" do
    test "a clear screen does not change the base level" do
      assert Risk.combine_aml(:low, :clear) == :low
      assert Risk.combine_aml(:medium, :clear) == :medium
    end

    test "a possible match escalates to at least medium" do
      assert Risk.combine_aml(:low, :possible_match) in [:medium, :high]
    end

    test "a confirmed match is high" do
      assert Risk.combine_aml(:low, :confirmed_match) == :high
    end
  end
end
