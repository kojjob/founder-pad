defmodule FounderPadWeb.Api.V1.EvidenceUploadControllerTest do
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  defp setup_key(scopes) do
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

  defp verification_for(org) do
    create_individual_verification!(%{organisation: org})
  end

  describe "POST /v1/individual_verifications/:id/evidence_uploads" do
    test "returns a signed upload URL and evidence id", %{conn: conn} do
      {org, key} = setup_key([:write])
      ivf = verification_for(org)

      conn =
        authed(conn, key)
        |> post(~p"/v1/individual_verifications/#{ivf.id}/evidence_uploads", %{
          "type" => "selfie",
          "content_type" => "image/jpeg"
        })

      body = json_response(conn, 201)
      assert body["evidence_id"]
      assert body["upload_url"] =~ "evidence/#{org.id}/"
      assert body["expires_at"]
    end

    test "rejects a read-only key", %{conn: conn} do
      {org, key} = setup_key([:read])
      ivf = verification_for(org)

      conn =
        authed(conn, key)
        |> post(~p"/v1/individual_verifications/#{ivf.id}/evidence_uploads", %{"type" => "selfie"})

      assert json_response(conn, 403)["error"]["code"] == "permission_denied"
    end

    test "404 for an unknown verification", %{conn: conn} do
      {_org, key} = setup_key([:write])

      conn =
        authed(conn, key)
        |> post(~p"/v1/individual_verifications/#{Ash.UUID.generate()}/evidence_uploads", %{
          "type" => "selfie"
        })

      assert json_response(conn, 404)["error"]["code"] == "verification_not_found"
    end

    test "does not allow uploading to another tenant's verification", %{conn: conn} do
      {_org_a, key_a} = setup_key([:write])
      other = create_organisation!()
      ivf = verification_for(other)

      conn =
        authed(conn, key_a)
        |> post(~p"/v1/individual_verifications/#{ivf.id}/evidence_uploads", %{"type" => "selfie"})

      assert json_response(conn, 404)["error"]["code"] == "verification_not_found"
    end

    test "422 for an invalid evidence type", %{conn: conn} do
      {org, key} = setup_key([:write])
      ivf = verification_for(org)

      conn =
        authed(conn, key)
        |> post(~p"/v1/individual_verifications/#{ivf.id}/evidence_uploads", %{"type" => "nope"})

      assert json_response(conn, 422)["error"]["code"] == "validation_failed"
    end
  end
end
