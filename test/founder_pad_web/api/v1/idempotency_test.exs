defmodule FounderPadWeb.Api.V1.IdempotencyTest do
  @moduledoc "Idempotency-Key header: safe retries, no duplicate work, conflict on reuse."
  use FounderPadWeb.ConnCase, async: true
  use Oban.Testing, repo: FounderPad.Repo
  import FounderPad.Factory

  alias FounderPad.Webhooks.Workers.WebhookDeliveryWorker

  defp write_key do
    user = create_user!()
    org = create_organisation!()
    create_membership!(user, org, :owner)
    {org, create_api_key!(org, user, %{scopes: [:write], mode: :test})}
  end

  defp post_with(key, idem_key, payload) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{key.__raw_key__}")
    |> put_req_header("content-type", "application/json")
    |> put_req_header("idempotency-key", idem_key)
    |> post(~p"/v1/individual_verifications", payload)
  end

  defp payload(card, ext \\ "c1") do
    %{"external_id" => ext, "person" => %{"ghana_card_number" => card}}
  end

  defp org_verification_count(org) do
    length(FounderPad.Compliance.list_individual_verifications_by_organisation!(org.id))
  end

  test "replays the original response and does not create a duplicate" do
    {org, key} = write_key()
    body = payload("GHA-TEST-VERIFIED-1")

    first = post_with(key, "idem-123", body)
    id1 = json_response(first, 201)["id"]

    second = post_with(key, "idem-123", body)
    assert json_response(second, 201)["id"] == id1

    assert org_verification_count(org) == 1
  end

  test "reusing a key with a different body is a conflict" do
    {_org, key} = write_key()

    post_with(key, "idem-xyz", payload("GHA-TEST-VERIFIED-1", "first"))
    conflict = post_with(key, "idem-xyz", payload("GHA-TEST-VERIFIED-1", "second"))

    assert json_response(conflict, 409)["error"]["code"] == "duplicate_idempotency_key"
  end

  test "different keys create different verifications" do
    {org, key} = write_key()

    post_with(key, "key-a", payload("GHA-TEST-VERIFIED-1", "a"))
    post_with(key, "key-b", payload("GHA-TEST-VERIFIED-1", "b"))

    assert org_verification_count(org) == 2
  end

  test "a replay does not fire a second webhook" do
    {org, key} = write_key()

    FounderPad.Webhooks.OutboundWebhook
    |> Ash.Changeset.for_create(:create, %{
      url: "https://example.com/wh",
      secret: "s",
      events: ["individual_verification.completed"],
      organisation_id: org.id
    })
    |> Ash.create!()

    body = payload("GHA-TEST-VERIFIED-1")
    post_with(key, "idem-wh", body)
    post_with(key, "idem-wh", body)

    assert length(all_enqueued(worker: WebhookDeliveryWorker)) == 1
  end
end
