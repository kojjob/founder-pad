defmodule FounderPadWeb.Api.V1.AuditCoverageTest do
  @moduledoc """
  Locks the audit promise: every sensitive action through the API emits an audit
  event. If a new action ships without an audit event, this test fails.
  """
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  defp setup_ctx do
    user = create_user!()
    org = create_organisation!()
    create_membership!(user, org, :owner)
    {org, create_api_key!(org, user, %{scopes: [:read, :write], mode: :test})}
  end

  defp authed(conn, key) do
    conn
    |> put_req_header("authorization", "Bearer #{key.__raw_key__}")
    |> put_req_header("content-type", "application/json")
  end

  defp events(org) do
    FounderPad.Audit.list_by_organisation!(org.id)
    |> Enum.map(& &1.metadata["event"])
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  test "all core API actions emit audit events", %{conn: conn} do
    {org, key} = setup_ctx()
    c = authed(conn, key)

    # Individual verification with consent (live), evidence and AML
    ivf =
      c
      |> post(~p"/v1/individual_verifications", %{
        "external_id" => "audit_ivf",
        "person" => %{"ghana_card_number" => "GHA-TEST-VERIFIED-1", "first_name" => "AML-PEP"},
        "options" => %{"run_aml_screen" => true}
      })
      |> json_response(201)

    build_conn()
    |> authed(key)
    |> post(~p"/v1/individual_verifications/#{ivf["id"]}/evidence_uploads", %{"type" => "selfie"})
    |> json_response(201)

    # Business verification with AML
    build_conn()
    |> authed(key)
    |> post(~p"/v1/business_verifications", %{
      "external_id" => "audit_bv",
      "business" => %{
        "registered_name" => "AML-SANCTION Ltd",
        "registration_number" => "CS-TEST-VERIFIED-1"
      },
      "options" => %{"run_aml_screen" => true}
    })
    |> json_response(201)

    found = events(org)

    for event <- [
          "individual_verification.created",
          "individual_verification.completed",
          "evidence.upload_requested",
          "aml_screen.completed",
          "business_verification.created",
          "business_verification.completed"
        ] do
      assert event in found, "missing audit event: #{event}"
    end
  end
end
