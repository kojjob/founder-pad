defmodule FounderPadWeb.Admin.ProviderHealthLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  test "admin sees configured providers and job health", %{conn: conn} do
    {conn, _admin, _org} = setup_authenticated_admin(conn)

    {:ok, _view, html} = live(conn, ~p"/admin/provider-health")

    assert html =~ "Provider Health"
    # The five swappable provider seams are listed.
    assert html =~ "Identity"
    assert html =~ "Liveness"
    assert html =~ "KYB"
    assert html =~ "AML"
    assert html =~ "Storage"
    # Sandbox providers report operational.
    assert html =~ "sandbox"
    assert html =~ "Failed jobs"
  end

  test "a non-admin cannot reach it", %{conn: conn} do
    {conn, _user, _org} = setup_authenticated_user(conn)
    assert {:error, {:live_redirect, _}} = live(conn, ~p"/admin/provider-health")
  end
end
