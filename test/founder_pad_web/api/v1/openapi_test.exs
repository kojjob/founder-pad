defmodule FounderPadWeb.Api.V1.OpenApiTest do
  @moduledoc "The /v1 OpenAPI document is served and structurally valid."
  use FounderPadWeb.ConnCase, async: true

  test "serves a valid OpenAPI 3 document (no API key required)", %{conn: conn} do
    body = conn |> get(~p"/v1/openapi.json") |> json_response(200)

    assert body["openapi"] =~ ~r/^3\./
    assert body["info"]["title"] =~ "GhanaTrust"
    assert body["info"]["version"]
  end

  test "documents the individual verification endpoints", %{conn: conn} do
    body = conn |> get(~p"/v1/openapi.json") |> json_response(200)

    assert get_in(body, ["paths", "/v1/individual_verifications", "post"])
    assert get_in(body, ["paths", "/v1/individual_verifications/{id}", "get"])
  end

  test "declares bearer API-key security and core schemas", %{conn: conn} do
    body = conn |> get(~p"/v1/openapi.json") |> json_response(200)

    assert get_in(body, ["components", "securitySchemes", "ApiKeyAuth", "scheme"]) == "bearer"
    assert get_in(body, ["components", "schemas", "IndividualVerification"])
    assert get_in(body, ["components", "schemas", "Error"])
  end
end
