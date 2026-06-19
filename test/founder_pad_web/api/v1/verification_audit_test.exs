defmodule FounderPadWeb.Api.V1.VerificationAuditTest do
  @moduledoc "Every verification created through the API must leave an audit trail."
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  defp post_verification(conn, scopes, mode, card) do
    user = create_user!()
    org = create_organisation!()
    create_membership!(user, org, :owner)
    key = create_api_key!(org, user, %{scopes: scopes, mode: mode})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{key.__raw_key__}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/v1/individual_verifications", %{
        "external_id" => "c1",
        "person" => %{"ghana_card_number" => card, "first_name" => "Ama"}
      })

    {org, conn}
  end

  defp events_for(org) do
    FounderPad.Audit.list_by_organisation!(org.id)
    |> Enum.map(& &1.metadata["event"])
  end

  test "records created and completed events for a processed verification", %{conn: conn} do
    {org, conn} = post_verification(conn, [:write], :test, "GHA-TEST-VERIFIED-1")
    assert json_response(conn, 201)

    events = events_for(org)
    assert "individual_verification.created" in events
    assert "individual_verification.completed" in events
  end

  test "audit log captures the resource id and api_key actor type", %{conn: conn} do
    {org, conn} = post_verification(conn, [:write], :test, "GHA-TEST-VERIFIED-1")
    id = json_response(conn, 201)["id"]

    log =
      FounderPad.Audit.list_by_organisation!(org.id)
      |> Enum.find(&(&1.metadata["event"] == "individual_verification.created"))

    assert log.resource_type == "IndividualVerification"
    assert log.resource_id == id
    assert log.metadata["actor_type"] == "api_key"
  end
end
