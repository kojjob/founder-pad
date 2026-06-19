defmodule FounderPadWeb.ReviewQueueLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "review queue" do
    test "lists the tenant's open review cases", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      Factory.create_review_case!(%{organisation: org})

      {:ok, _view, html} = live(conn, ~p"/reviews")

      assert html =~ "Review Queue"
      assert html =~ "individual_verification"
    end

    test "approving a case requires a reason and closes it", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      review = Factory.create_review_case!(%{organisation: org})

      {:ok, view, _html} = live(conn, ~p"/reviews")

      view
      |> form("#decision-#{review.id}", %{"decision_reason" => "Verified documents in person"})
      |> render_submit(%{"_target" => ["approve"], "decision" => "approve"})

      reloaded = Ash.get!(FounderPad.Compliance.ReviewCase, review.id)
      assert reloaded.status == :approved
      assert reloaded.decision_reason == "Verified documents in person"
    end

    test "a decision writes an audit event", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      review = Factory.create_review_case!(%{organisation: org})

      {:ok, view, _html} = live(conn, ~p"/reviews")

      view
      |> form("#decision-#{review.id}", %{"decision_reason" => "Looks fraudulent"})
      |> render_submit(%{"decision" => "reject"})

      events =
        FounderPad.Audit.list_by_organisation!(org.id)
        |> Enum.map(& &1.metadata["event"])

      assert "review_case.rejected" in events
    end
  end
end
