defmodule FounderPadWeb.Admin.FeatureFlagsLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  describe "admin feature flags" do
    test "admin can see feature flags", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      FounderPad.FeatureFlags.FeatureFlag
      |> Ash.Changeset.for_create(:create, %{key: "test_flag", name: "Test Flag", enabled: true})
      |> Ash.create!()

      {:ok, _view, html} = live(conn, ~p"/admin/feature-flags")

      assert html =~ "Feature Flags"
      assert html =~ "Test Flag"
      assert html =~ "test_flag"
    end

    test "admin can toggle a flag off", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      flag =
        FounderPad.FeatureFlags.FeatureFlag
        |> Ash.Changeset.for_create(:create, %{key: "toggle_me", name: "Toggle Me", enabled: true})
        |> Ash.create!()

      {:ok, view, _html} = live(conn, ~p"/admin/feature-flags")

      view
      |> element(~s|button[phx-click=toggle][phx-value-id="#{flag.id}"]|)
      |> render_click()

      reloaded = Ash.get!(FounderPad.FeatureFlags.FeatureFlag, flag.id)
      refute reloaded.enabled
    end

    test "admin can toggle a flag on", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      flag =
        FounderPad.FeatureFlags.FeatureFlag
        |> Ash.Changeset.for_create(:create, %{key: "off_flag", name: "Off Flag", enabled: false})
        |> Ash.create!()

      {:ok, view, _html} = live(conn, ~p"/admin/feature-flags")

      view
      |> element(~s|button[phx-click=toggle][phx-value-id="#{flag.id}"]|)
      |> render_click()

      reloaded = Ash.get!(FounderPad.FeatureFlags.FeatureFlag, flag.id)
      assert reloaded.enabled
    end

    test "non-admin is redirected", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      assert {:error, {:live_redirect, _}} = live(conn, ~p"/admin/feature-flags")
    end
  end
end
