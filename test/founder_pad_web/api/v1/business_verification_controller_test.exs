defmodule FounderPadWeb.Api.V1.BusinessVerificationControllerTest do
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

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

  defp payload(reg, ext \\ "merchant_1") do
    %{
      "external_id" => ext,
      "business" => %{
        "registered_name" => "Example Trading Ltd",
        "registration_number" => reg,
        "tin" => "P0001234567"
      }
    }
  end

  describe "POST /v1/business_verifications" do
    test "creates and processes a KYB check", %{conn: conn} do
      {_org, key} = key_for([:write])

      conn =
        authed(conn, key) |> post(~p"/v1/business_verifications", payload("CS-TEST-VERIFIED-1"))

      body = json_response(conn, 201)
      assert body["id"]
      assert body["status"] == "verified"
      assert body["mode"] == "test"
    end

    test "routes a review fixture to requires_review", %{conn: conn} do
      {_org, key} = key_for([:write])

      conn =
        authed(conn, key) |> post(~p"/v1/business_verifications", payload("CS-TEST-REVIEW-1"))

      assert json_response(conn, 201)["status"] == "requires_review"
    end

    test "rejects without an API key", %{conn: conn} do
      conn = post(conn, ~p"/v1/business_verifications", payload("CS-TEST-VERIFIED-1"))
      assert json_response(conn, 401)["error"]["code"] == "authentication_failed"
    end

    test "rejects a read-only key", %{conn: conn} do
      {_org, key} = key_for([:read])

      conn =
        authed(conn, key) |> post(~p"/v1/business_verifications", payload("CS-TEST-VERIFIED-1"))

      assert json_response(conn, 403)["error"]["code"] == "permission_denied"
    end

    test "validates the payload", %{conn: conn} do
      {_org, key} = key_for([:write])
      conn = authed(conn, key) |> post(~p"/v1/business_verifications", %{"business" => %{}})
      assert json_response(conn, 422)["error"]["code"] == "validation_failed"
    end

    test "is idempotent on external_id", %{conn: conn} do
      {_org, key} = key_for([:write])
      body = payload("CS-TEST-VERIFIED-1", "stable")

      first = authed(conn, key) |> post(~p"/v1/business_verifications", body)
      id1 = json_response(first, 201)["id"]

      second = build_conn() |> authed(key) |> post(~p"/v1/business_verifications", body)
      assert json_response(second, 200)["id"] == id1
    end
  end

  describe "GET /v1/business_verifications/:id" do
    test "returns the KYB detail", %{conn: conn} do
      {_org, key} = key_for([:read, :write])

      created =
        authed(conn, key) |> post(~p"/v1/business_verifications", payload("CS-TEST-VERIFIED-1"))

      id = json_response(created, 201)["id"]

      shown = build_conn() |> authed(key) |> get(~p"/v1/business_verifications/#{id}")
      body = json_response(shown, 200)

      assert body["id"] == id
      assert body["status"] == "verified"
      assert body["business"]["registered_name"] == "Example Trading Ltd"
      assert body["risk"]["level"] == "low"
    end

    test "404 for unknown id", %{conn: conn} do
      {_org, key} = key_for([:read])
      shown = authed(conn, key) |> get(~p"/v1/business_verifications/#{Ash.UUID.generate()}")
      assert json_response(shown, 404)["error"]["code"] == "business_verification_not_found"
    end

    test "does not leak another tenant's KYB check", %{conn: conn} do
      {_org_a, key_a} = key_for([:write])
      {_org_b, key_b} = key_for([:read])

      created =
        authed(conn, key_a) |> post(~p"/v1/business_verifications", payload("CS-TEST-VERIFIED-1"))

      id = json_response(created, 201)["id"]

      shown = build_conn() |> authed(key_b) |> get(~p"/v1/business_verifications/#{id}")
      assert json_response(shown, 404)["error"]["code"] == "business_verification_not_found"
    end
  end
end
