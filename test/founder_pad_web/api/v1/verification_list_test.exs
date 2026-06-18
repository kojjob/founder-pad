defmodule FounderPadWeb.Api.V1.VerificationListTest do
  @moduledoc "GET /v1 collection endpoints: tenant-scoped, paginated, filterable."
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  defp key_for(scopes) do
    user = create_user!()
    org = create_organisation!()
    create_membership!(user, org, :owner)
    {org, create_api_key!(org, user, %{scopes: scopes, mode: :test})}
  end

  defp authed(conn, key) do
    put_req_header(conn, "authorization", "Bearer #{key.__raw_key__}")
  end

  describe "GET /v1/individual_verifications" do
    test "lists the tenant's verifications with a pagination envelope", %{conn: conn} do
      {org, key} = key_for([:read])
      create_individual_verification!(%{organisation: org, external_id: "a"})
      create_individual_verification!(%{organisation: org, external_id: "b"})

      body = authed(conn, key) |> get(~p"/v1/individual_verifications") |> json_response(200)

      assert length(body["data"]) == 2
      assert body["pagination"]["limit"]
      assert Enum.all?(body["data"], &is_map/1)
    end

    test "does not include another tenant's verifications", %{conn: conn} do
      {_org, key} = key_for([:read])
      other = create_organisation!()
      create_individual_verification!(%{organisation: other, external_id: "secret"})

      body = authed(conn, key) |> get(~p"/v1/individual_verifications") |> json_response(200)
      assert body["data"] == []
    end

    test "filters by status", %{conn: conn} do
      {org, key} = key_for([:read])

      create_individual_verification!(%{
        organisation: org,
        ghana_card_number: "GHA-TEST-VERIFIED-1"
      })

      create_individual_verification!(%{
        organisation: org,
        ghana_card_number: "GHA-TEST-VERIFIED-1"
      })

      # All seeded checks are :pending (not processed); filter on a status with none.
      body =
        authed(conn, key)
        |> get(~p"/v1/individual_verifications?status=verified")
        |> json_response(200)

      assert body["data"] == []
    end

    test "respects the limit", %{conn: conn} do
      {org, key} = key_for([:read])

      for i <- 1..3,
          do: create_individual_verification!(%{organisation: org, external_id: "x#{i}"})

      body =
        authed(conn, key) |> get(~p"/v1/individual_verifications?limit=2") |> json_response(200)

      assert length(body["data"]) == 2
      assert body["pagination"]["limit"] == 2
    end

    test "requires a read scope", %{conn: conn} do
      {_org, key} = key_for([])
      conn = authed(conn, key) |> get(~p"/v1/individual_verifications")
      assert json_response(conn, 403)["error"]["code"] == "permission_denied"
    end

    test "requires an API key", %{conn: conn} do
      assert json_response(get(conn, ~p"/v1/individual_verifications"), 401)
    end
  end

  describe "GET /v1/business_verifications" do
    test "lists the tenant's KYB checks", %{conn: conn} do
      {org, key} = key_for([:read])
      create_business_verification!(%{organisation: org})

      body = authed(conn, key) |> get(~p"/v1/business_verifications") |> json_response(200)
      assert length(body["data"]) == 1
    end
  end
end
