defmodule FounderPadWeb.Api.V1.AmlWiringTest do
  @moduledoc "run_aml_screen option triggers an AML screen and routes hits to review."
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  defp write_key do
    user = create_user!()
    org = create_organisation!()
    create_membership!(user, org, :owner)
    {org, create_api_key!(org, user, %{scopes: [:write], mode: :test})}
  end

  defp authed(conn, key) do
    conn
    |> put_req_header("authorization", "Bearer #{key.__raw_key__}")
    |> put_req_header("content-type", "application/json")
  end

  test "individual verification with run_aml_screen + PEP name opens an AML review", %{conn: conn} do
    {org, key} = write_key()

    authed(conn, key)
    |> post(~p"/v1/individual_verifications", %{
      "external_id" => "c_aml",
      "person" => %{
        "ghana_card_number" => "GHA-TEST-VERIFIED-1",
        "first_name" => "AML-PEP",
        "last_name" => "Person"
      },
      "options" => %{"run_aml_screen" => true}
    })
    |> json_response(201)

    screens = FounderPad.Compliance.list_aml_screens_by_organisation!(org.id)
    assert [screen] = screens
    assert screen.status == :possible_match

    cases = FounderPad.Compliance.list_open_review_cases!(org.id)
    assert Enum.any?(cases, &(&1.subject_type == :aml_screen))
  end

  test "without run_aml_screen no screen is run", %{conn: conn} do
    {org, key} = write_key()

    authed(conn, key)
    |> post(~p"/v1/individual_verifications", %{
      "external_id" => "c_noaml",
      "person" => %{"ghana_card_number" => "GHA-TEST-VERIFIED-1", "first_name" => "AML-PEP"}
    })
    |> json_response(201)

    assert FounderPad.Compliance.list_aml_screens_by_organisation!(org.id) == []
  end

  test "business verification with run_aml_screen screens the registered name", %{conn: conn} do
    {org, key} = write_key()

    authed(conn, key)
    |> post(~p"/v1/business_verifications", %{
      "external_id" => "m_aml",
      "business" => %{
        "registered_name" => "AML-SANCTION Trading",
        "registration_number" => "CS-TEST-VERIFIED-1"
      },
      "options" => %{"run_aml_screen" => true}
    })
    |> json_response(201)

    assert [screen] = FounderPad.Compliance.list_aml_screens_by_organisation!(org.id)
    assert screen.subject_type == :business
    assert screen.status == :possible_match
  end
end
