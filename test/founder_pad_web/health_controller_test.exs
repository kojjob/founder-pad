defmodule FounderPadWeb.HealthControllerTest do
  use FounderPadWeb.ConnCase, async: true

  test "GET /health returns ok without auth", %{conn: conn} do
    body = conn |> get(~p"/health") |> json_response(200)
    assert body["status"] == "ok"
  end
end
