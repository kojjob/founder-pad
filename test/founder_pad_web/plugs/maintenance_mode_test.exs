defmodule FounderPadWeb.Plugs.MaintenanceModeTest do
  use FounderPadWeb.ConnCase, async: false
  alias FounderPadWeb.Plugs.MaintenanceMode

  describe "call/2" do
    test "passes through when maintenance is disabled", %{conn: conn} do
      conn = MaintenanceMode.call(conn, [])
      refute conn.halted
    end

    test "returns 503 when MAINTENANCE_MODE env var is set", %{conn: conn} do
      System.put_env("MAINTENANCE_MODE", "true")

      conn = MaintenanceMode.call(conn, [])

      assert conn.status == 503
      assert conn.halted
      assert conn.resp_body =~ "We'll be right back"
      assert conn.resp_body =~ "construction"
    after
      System.delete_env("MAINTENANCE_MODE")
    end

    test "allows bypass with correct cookie", %{conn: conn} do
      System.put_env("MAINTENANCE_MODE", "true")

      conn =
        conn
        |> put_req_cookie("maintenance_bypass", "dev-bypass")
        |> Plug.Conn.fetch_cookies()
        |> MaintenanceMode.call([])

      refute conn.halted
    after
      System.delete_env("MAINTENANCE_MODE")
    end

    test "does not allow bypass with incorrect cookie", %{conn: conn} do
      System.put_env("MAINTENANCE_MODE", "true")

      conn =
        conn
        |> put_req_cookie("maintenance_bypass", "wrong-secret")
        |> Plug.Conn.fetch_cookies()
        |> MaintenanceMode.call([])

      assert conn.status == 503
      assert conn.halted
    after
      System.delete_env("MAINTENANCE_MODE")
    end
  end
end
