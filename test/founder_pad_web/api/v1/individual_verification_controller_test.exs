defmodule FounderPadWeb.Api.V1.IndividualVerificationControllerTest do
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  defp authed_conn(conn, key) do
    conn
    |> put_req_header("authorization", "Bearer #{key.__raw_key__}")
    |> put_req_header("content-type", "application/json")
  end

  defp key_for(scopes, mode) do
    user = create_user!()
    org = create_organisation!()
    create_membership!(user, org, :owner)
    {org, create_api_key!(org, user, %{scopes: scopes, mode: mode})}
  end

  defp valid_payload(overrides \\ %{}) do
    Map.merge(
      %{
        "external_id" => "customer_#{System.unique_integer([:positive])}",
        "person" => %{
          "ghana_card_number" => "GHA-TEST-VERIFIED-1",
          "first_name" => "Ama",
          "last_name" => "Mensah",
          "date_of_birth" => "1995-04-12",
          "phone_number" => "+233241234567"
        }
      },
      overrides
    )
  end

  describe "POST /v1/individual_verifications" do
    test "creates and processes a verification with a test key", %{conn: conn} do
      {_org, key} = key_for([:read, :write], :test)

      conn = authed_conn(conn, key) |> post(~p"/v1/individual_verifications", valid_payload())

      body = json_response(conn, 201)
      assert body["id"]
      assert body["mode"] == "test"
      assert body["status"] == "verified"
      assert body["external_id"]
      assert body["links"]["self"] =~ body["id"]
    end

    test "routes a review fixture to requires_review", %{conn: conn} do
      {_org, key} = key_for([:write], :test)
      payload = valid_payload(%{"person" => %{"ghana_card_number" => "GHA-TEST-REVIEW-1"}})

      conn = authed_conn(conn, key) |> post(~p"/v1/individual_verifications", payload)
      assert json_response(conn, 201)["status"] == "requires_review"
    end

    test "rejects requests without an API key", %{conn: conn} do
      conn = post(conn, ~p"/v1/individual_verifications", valid_payload())
      assert json_response(conn, 401)["error"]["code"] == "authentication_failed"
    end

    test "rejects a read-only key with permission_denied", %{conn: conn} do
      {_org, key} = key_for([:read], :test)
      conn = authed_conn(conn, key) |> post(~p"/v1/individual_verifications", valid_payload())
      assert json_response(conn, 403)["error"]["code"] == "permission_denied"
    end

    test "requires consent in live mode", %{conn: conn} do
      {_org, key} = key_for([:write], :live)
      conn = authed_conn(conn, key) |> post(~p"/v1/individual_verifications", valid_payload())
      assert json_response(conn, 422)["error"]["code"] == "consent_required"
    end

    test "accepts live mode when consent is supplied", %{conn: conn} do
      {_org, key} = key_for([:write], :live)

      payload =
        valid_payload(%{
          "consent" => %{
            "purpose" => "customer_onboarding",
            "channel" => "api",
            "accepted_at" => "2026-06-17T12:00:00Z",
            "privacy_notice_version" => "2026-01"
          }
        })

      conn = authed_conn(conn, key) |> post(~p"/v1/individual_verifications", payload)
      assert json_response(conn, 201)["mode"] == "live"
    end

    test "validates the payload", %{conn: conn} do
      {_org, key} = key_for([:write], :test)
      payload = %{"external_id" => "x", "person" => %{"first_name" => "Ama"}}

      conn = authed_conn(conn, key) |> post(~p"/v1/individual_verifications", payload)
      assert json_response(conn, 422)["error"]["code"] == "validation_failed"
    end

    test "is idempotent on external_id within a tenant", %{conn: conn} do
      {_org, key} = key_for([:write], :test)
      payload = valid_payload(%{"external_id" => "stable_id"})

      first = authed_conn(conn, key) |> post(~p"/v1/individual_verifications", payload)
      id1 = json_response(first, 201)["id"]

      second =
        build_conn() |> authed_conn(key) |> post(~p"/v1/individual_verifications", payload)

      assert json_response(second, 200)["id"] == id1
    end
  end

  describe "GET /v1/individual_verifications/:id" do
    test "returns the verification detail", %{conn: conn} do
      {_org, key} = key_for([:read, :write], :test)

      created =
        authed_conn(conn, key) |> post(~p"/v1/individual_verifications", valid_payload())

      id = json_response(created, 201)["id"]

      shown = build_conn() |> authed_conn(key) |> get(~p"/v1/individual_verifications/#{id}")
      body = json_response(shown, 200)

      assert body["id"] == id
      assert body["status"] == "verified"
      assert body["identity"]["verified"] == true
      assert body["risk"]["level"] == "low"
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      {_org, key} = key_for([:read], :test)
      id = Ash.UUID.generate()

      shown = authed_conn(conn, key) |> get(~p"/v1/individual_verifications/#{id}")
      assert json_response(shown, 404)["error"]["code"] == "verification_not_found"
    end

    test "does not leak verifications from another tenant", %{conn: conn} do
      {_org_a, key_a} = key_for([:read, :write], :test)
      {_org_b, key_b} = key_for([:read], :test)

      created =
        authed_conn(conn, key_a) |> post(~p"/v1/individual_verifications", valid_payload())

      id = json_response(created, 201)["id"]

      shown = build_conn() |> authed_conn(key_b) |> get(~p"/v1/individual_verifications/#{id}")
      assert json_response(shown, 404)["error"]["code"] == "verification_not_found"
    end
  end
end
