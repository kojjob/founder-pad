defmodule FounderPadWeb.Api.V1.WebhookControllerTest do
  @moduledoc "Developer-facing webhook management via /v1 (endpoints, deliveries, retry)."
  use FounderPadWeb.ConnCase, async: true
  use Oban.Testing, repo: FounderPad.Repo
  import FounderPad.Factory

  alias FounderPad.Webhooks.Workers.WebhookDeliveryWorker

  defp key_for(scopes) do
    user = create_user!()
    org = create_organisation!()
    create_membership!(user, org, :owner)
    {org, create_api_key!(org, user, %{scopes: scopes, mode: :test})}
  end

  defp authed(conn, key) do
    conn
    |> put_req_header("authorization", "Bearer #{key.__raw_key__}")
    |> put_req_header("content-type", "application/json")
  end

  defp endpoint(org) do
    FounderPad.Webhooks.OutboundWebhook
    |> Ash.Changeset.for_create(:create, %{
      url: "https://e.com/wh",
      secret: "whsec_x",
      events: ["individual_verification.completed"],
      organisation_id: org.id
    })
    |> Ash.create!()
  end

  defp delivery(wh) do
    FounderPad.Webhooks.WebhookDelivery
    |> Ash.Changeset.for_create(:create, %{
      event_type: "individual_verification.completed",
      payload: %{"id" => "x"},
      webhook_id: wh.id
    })
    |> Ash.create!()
  end

  describe "POST /v1/webhook_endpoints" do
    test "creates an endpoint and returns the secret once", %{conn: conn} do
      {_org, key} = key_for([:write])

      body =
        authed(conn, key)
        |> post(~p"/v1/webhook_endpoints", %{
          "url" => "https://client.example.com/wh",
          "events" => ["individual_verification.completed"]
        })
        |> json_response(201)

      assert body["id"]
      assert body["url"] == "https://client.example.com/wh"
      assert body["secret"] =~ ~r/^whsec_/
    end

    test "requires a write scope", %{conn: conn} do
      {_org, key} = key_for([:read])
      conn = authed(conn, key) |> post(~p"/v1/webhook_endpoints", %{"url" => "https://x"})
      assert json_response(conn, 403)["error"]["code"] == "permission_denied"
    end
  end

  describe "GET /v1/webhook_endpoints" do
    test "lists the tenant's endpoints without leaking the secret", %{conn: conn} do
      {org, key} = key_for([:read])
      endpoint(org)

      body = authed(conn, key) |> get(~p"/v1/webhook_endpoints") |> json_response(200)

      assert length(body["data"]) == 1
      refute Map.has_key?(hd(body["data"]), "secret")
    end

    test "does not list another tenant's endpoints", %{conn: conn} do
      {_org, key} = key_for([:read])
      other = create_organisation!()
      endpoint(other)

      body = authed(conn, key) |> get(~p"/v1/webhook_endpoints") |> json_response(200)
      assert body["data"] == []
    end
  end

  describe "GET /v1/webhook_deliveries" do
    test "lists deliveries for an endpoint", %{conn: conn} do
      {org, key} = key_for([:read])
      wh = endpoint(org)
      delivery(wh)

      body =
        authed(conn, key)
        |> get(~p"/v1/webhook_deliveries?webhook_endpoint_id=#{wh.id}")
        |> json_response(200)

      assert length(body["data"]) == 1
    end
  end

  describe "POST /v1/webhook_deliveries/:id/retry" do
    test "re-enqueues a delivery", %{conn: conn} do
      {org, key} = key_for([:write])
      wh = endpoint(org)
      d = delivery(wh)

      conn = authed(conn, key) |> post(~p"/v1/webhook_deliveries/#{d.id}/retry")
      assert json_response(conn, 202)["status"] == "retrying"
      assert_enqueued(worker: WebhookDeliveryWorker)
    end

    test "cannot retry another tenant's delivery", %{conn: conn} do
      {_org, key} = key_for([:write])
      other = create_organisation!()
      d = delivery(endpoint(other))

      conn = authed(conn, key) |> post(~p"/v1/webhook_deliveries/#{d.id}/retry")
      assert json_response(conn, 404)["error"]["code"] == "delivery_not_found"
    end
  end
end
