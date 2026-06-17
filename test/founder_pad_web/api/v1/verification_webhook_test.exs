defmodule FounderPadWeb.Api.V1.VerificationWebhookTest do
  @moduledoc "Verification lifecycle outcomes dispatch signed webhooks to subscribers."
  use FounderPadWeb.ConnCase, async: true
  use Oban.Testing, repo: FounderPad.Repo
  import FounderPad.Factory

  alias FounderPad.Webhooks.Workers.WebhookDeliveryWorker

  defp setup_org_with_webhook(events) do
    user = create_user!()
    org = create_organisation!()
    create_membership!(user, org, :owner)
    key = create_api_key!(org, user, %{scopes: [:write], mode: :test})

    FounderPad.Webhooks.OutboundWebhook
    |> Ash.Changeset.for_create(:create, %{
      url: "https://client.example.com/webhooks/ghanatrust",
      secret: "whsec_test",
      events: events,
      organisation_id: org.id
    })
    |> Ash.create!()

    {org, key}
  end

  defp post_card(conn, key, card) do
    conn
    |> put_req_header("authorization", "Bearer #{key.__raw_key__}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/v1/individual_verifications", %{
      "external_id" => "c1",
      "person" => %{"ghana_card_number" => card}
    })
  end

  test "a completed verification enqueues a delivery for subscribers", %{conn: conn} do
    {_org, key} = setup_org_with_webhook(["individual_verification.completed"])

    assert json_response(post_card(conn, key, "GHA-TEST-VERIFIED-1"), 201)["status"] == "verified"

    assert_enqueued(
      worker: WebhookDeliveryWorker,
      args: %{event_type: "individual_verification.completed"}
    )
  end

  test "a review outcome enqueues a requires_review delivery", %{conn: conn} do
    {_org, key} = setup_org_with_webhook(["individual_verification.requires_review"])

    assert json_response(post_card(conn, key, "GHA-TEST-REVIEW-1"), 201)["status"] ==
             "requires_review"

    assert_enqueued(
      worker: WebhookDeliveryWorker,
      args: %{event_type: "individual_verification.requires_review"}
    )
  end

  test "does not dispatch to webhooks that did not subscribe to the event", %{conn: conn} do
    {_org, key} = setup_org_with_webhook(["business_verification.completed"])

    post_card(conn, key, "GHA-TEST-VERIFIED-1")

    refute_enqueued(worker: WebhookDeliveryWorker)
  end
end
