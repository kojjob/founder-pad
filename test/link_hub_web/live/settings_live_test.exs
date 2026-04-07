defmodule LinkHubWeb.SettingsLiveTest do
  use LinkHubWeb.ConnCase, async: true
  use LinkHub.LiveViewHelpers

  describe "settings page" do
    test "renders settings page with current user info", %{conn: conn} do
      {conn, user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Settings"
      assert html =~ "General Profile"
      assert html =~ "Security"
      assert html =~ to_string(user.email)
    end

    test "password change with correct current password succeeds", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/settings")

      # Open the password change form
      view |> element("button[phx-click=show_password_form]") |> render_click()

      # Submit password change
      result =
        view
        |> form("#password-form", %{
          "password" => %{
            "current_password" => "Password123!",
            "password" => "NewPassword456!",
            "password_confirmation" => "NewPassword456!"
          }
        })
        |> render_submit()

      assert result =~ "Password changed successfully"
    end

    test "password change with wrong current password fails", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/settings")

      # Open the password change form
      view |> element("button[phx-click=show_password_form]") |> render_click()

      # Submit with wrong current password
      result =
        view
        |> form("#password-form", %{
          "password" => %{
            "current_password" => "WrongPassword!",
            "password" => "NewPassword456!",
            "password_confirmation" => "NewPassword456!"
          }
        })
        |> render_submit()

      assert result =~ "is incorrect"
    end

    test "save preferences persists theme and UI settings", %{conn: conn} do
      {conn, user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/settings")

      # Toggle compact UI
      view |> element("button[phx-click=toggle_compact_ui]") |> render_click()

      # Toggle high contrast
      view |> element("button[phx-click=toggle_high_contrast]") |> render_click()

      # Select light theme
      view |> element("button[phx-click=select_theme][phx-value-theme=light]") |> render_click()

      # Save preferences
      result = view |> element("button[phx-click=save_preferences]") |> render_click()

      assert result =~ "Preferences saved successfully"

      # Reload user and verify preferences persisted
      {:ok, updated_user} = Ash.get(LinkHub.Accounts.User, user.id)
      assert updated_user.preferences["theme"] == "light"
      assert updated_user.preferences["compact_ui"] == true
      assert updated_user.preferences["high_contrast"] == true
    end
  end
end
