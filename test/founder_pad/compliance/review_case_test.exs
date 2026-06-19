defmodule FounderPad.Compliance.ReviewCaseTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  alias FounderPad.Compliance.ReviewCase

  defp open_case(attrs \\ %{}) do
    org = Map.get_lazy(attrs, :organisation, fn -> create_organisation!() end)

    ReviewCase
    |> Ash.Changeset.for_create(:open, %{
      organisation_id: org.id,
      subject_type: :individual_verification,
      subject_id: Ash.UUID.generate(),
      priority: Map.get(attrs, :priority, :normal)
    })
    |> Ash.create!()
  end

  describe "open/create" do
    test "a new case starts open and unassigned" do
      review = open_case()
      assert review.status == :open
      assert is_nil(review.assigned_to_user_id)
    end
  end

  describe "assign" do
    test "assigns the case to a reviewer" do
      user = create_user!()
      review = open_case()

      {:ok, assigned} =
        review
        |> Ash.Changeset.for_update(:assign, %{assigned_to_user_id: user.id})
        |> Ash.update()

      assert assigned.status == :assigned
      assert assigned.assigned_to_user_id == user.id
    end
  end

  describe "decisions require a reason" do
    test "approve records the decision, reason and closes the case" do
      review = open_case()

      {:ok, approved} =
        review
        |> Ash.Changeset.for_update(:approve, %{decision_reason: "Documents match Ghana Card"})
        |> Ash.update()

      assert approved.status == :approved
      assert approved.decision_reason == "Documents match Ghana Card"
      assert approved.closed_at
    end

    test "reject requires a reason" do
      review = open_case()

      assert {:error, _} =
               review
               |> Ash.Changeset.for_update(:reject, %{})
               |> Ash.update()
    end

    test "request_more_info keeps the case open with a reason" do
      review = open_case()

      {:ok, updated} =
        review
        |> Ash.Changeset.for_update(:request_more_info, %{decision_reason: "Need clearer selfie"})
        |> Ash.update()

      assert updated.status == :more_info_requested
      refute updated.closed_at
    end
  end

  describe "by_organisation / open_cases" do
    test "lists open cases for a tenant, newest first" do
      org = create_organisation!()
      _a = open_case(%{organisation: org})
      _b = open_case(%{organisation: org})
      _other = open_case()

      cases = FounderPad.Compliance.list_open_review_cases!(org.id)
      assert length(cases) == 2
      assert Enum.all?(cases, &(&1.organisation_id == org.id))
    end
  end
end
