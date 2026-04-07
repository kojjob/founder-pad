defmodule FounderPadWeb.UnsubscribeControllerTest do
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  test "unsubscribes with valid token", %{conn: conn} do
    user = create_user!()
    token = Phoenix.Token.sign(FounderPadWeb.Endpoint, "unsubscribe", {user.id, "marketing"})

    conn = get(conn, "/unsubscribe/#{token}")
    assert response(conn, 200) =~ "Unsubscribed"

    reloaded = Ash.get!(FounderPad.Accounts.User, user.id)
    assert reloaded.email_preferences["marketing"] == false
  end

  test "rejects invalid token", %{conn: conn} do
    conn = get(conn, "/unsubscribe/invalid_token")
    assert response(conn, 400) =~ "Expired"
  end
end
