defmodule FounderPadWeb.ApiKeysLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "API keys page" do
    test "user can see their API keys", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      Factory.create_api_key!(org, user, %{name: "My Key"})

      {:ok, _view, html} = live(conn, ~p"/api-keys")

      assert html =~ "API Keys"
      assert html =~ "My Key"
    end

    test "user can create a new API key", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/api-keys")

      view |> element("button", "New API Key") |> render_click()

      html =
        view
        |> element("form[phx-submit=create]")
        |> render_submit(%{"name" => "Production Key", "scopes" => ["read", "write"]})

      # Should show the raw key (starts with fp_ prefix in the key_prefix column)
      assert html =~ "Your new API key"
      assert html =~ "Production Key"
    end

    test "user can revoke an API key", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      key = Factory.create_api_key!(org, user, %{name: "Revoke Me"})

      {:ok, view, _html} = live(conn, ~p"/api-keys")

      view
      |> element(~s|button[phx-click=revoke][phx-value-id="#{key.id}"]|)
      |> render_click()

      reloaded = Ash.get!(FounderPad.ApiKeys.ApiKey, key.id)
      assert reloaded.revoked_at
    end

    test "user can dismiss the raw key display", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/api-keys")

      view |> element("button", "New API Key") |> render_click()

      view
      |> element("form[phx-submit=create]")
      |> render_submit(%{"name" => "Temp Key", "scopes" => ["read"]})

      html =
        view
        |> element("button", "I've copied my key")
        |> render_click()

      refute html =~ "Your new API key"
    end

    test "shows empty state when no keys exist", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/api-keys")

      assert html =~ "No API keys yet"
    end
  end
end
