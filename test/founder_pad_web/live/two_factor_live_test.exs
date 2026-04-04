defmodule FounderPadWeb.TwoFactorLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Accounts.UserTotp

  describe "two-factor settings page" do
    test "renders 2FA setup page when not enabled", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, _view, html} = live(conn, ~p"/settings/two-factor")

      assert html =~ "Two-Factor Authentication"
      assert html =~ "Enable 2FA"
    end

    test "shows 2FA as enabled when already set up", %{conn: conn} do
      {conn, user, _org} = setup_authenticated_user(conn)

      # Create and enable TOTP for the user
      totp =
        UserTotp
        |> Ash.Changeset.for_create(:create, %{user_id: user.id})
        |> Ash.create!()

      totp
      |> Ash.Changeset.for_update(:enable, %{})
      |> Ash.update!()

      {:ok, _view, html} = live(conn, ~p"/settings/two-factor")

      assert html =~ "Two-Factor Authentication"
      assert html =~ "Enabled"
    end

    test "clicking enable generates setup info with otpauth URI", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/settings/two-factor")

      html = view |> element("button", "Enable 2FA") |> render_click()

      assert html =~ "otpauth://"
      assert html =~ "Verify Code"
    end

    test "verifying with correct code enables 2FA and shows backup codes", %{conn: conn} do
      {conn, user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/settings/two-factor")

      # Start setup
      view |> element("button", "Enable 2FA") |> render_click()

      # Get the TOTP record that was created
      {:ok, [totp]} =
        UserTotp
        |> Ash.Query.for_read(:by_user, %{user_id: user.id})
        |> Ash.read()

      # Compute valid code
      time = System.system_time(:second)
      counter = div(time, 30)
      code = compute_test_totp(totp.secret, counter)

      html =
        view
        |> form("#verify-totp-form", %{"code" => code})
        |> render_submit()

      assert html =~ "Backup Codes"
      assert html =~ "Two-factor authentication enabled"
    end

    test "verifying with wrong code shows error", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      {:ok, view, _html} = live(conn, ~p"/settings/two-factor")

      # Start setup
      view |> element("button", "Enable 2FA") |> render_click()

      html =
        view
        |> form("#verify-totp-form", %{"code" => "000000"})
        |> render_submit()

      assert html =~ "Invalid code"
    end

    test "disable 2FA removes TOTP", %{conn: conn} do
      {conn, user, _org} = setup_authenticated_user(conn)

      # Create and enable TOTP
      totp =
        UserTotp
        |> Ash.Changeset.for_create(:create, %{user_id: user.id})
        |> Ash.create!()

      totp
      |> Ash.Changeset.for_update(:enable, %{})
      |> Ash.update!()

      {:ok, view, _html} = live(conn, ~p"/settings/two-factor")

      html = view |> element("button", "Disable 2FA") |> render_click()

      assert html =~ "Two-factor authentication disabled"

      # Verify TOTP is disabled
      {:ok, [updated_totp]} =
        UserTotp
        |> Ash.Query.for_read(:by_user, %{user_id: user.id})
        |> Ash.read()

      refute updated_totp.enabled
    end
  end

  defp compute_test_totp(secret, counter) do
    key = Base.decode32!(secret, padding: false)
    msg = <<counter::unsigned-big-integer-size(64)>>
    hmac = :crypto.mac(:hmac, :sha, key, msg)
    offset = :binary.at(hmac, byte_size(hmac) - 1) &&& 0x0F
    <<_::binary-size(offset), code::unsigned-big-integer-size(32), _::binary>> = hmac
    otp = rem(code &&& 0x7FFFFFFF, 1_000_000)
    String.pad_leading(Integer.to_string(otp), 6, "0")
  end
end
