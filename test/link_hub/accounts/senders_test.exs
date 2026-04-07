defmodule LinkHub.Accounts.SendersTest do
  use LinkHub.DataCase, async: true
  import LinkHub.Factory

  alias LinkHub.Accounts.Senders.{MagicLinkSender, PasswordResetSender}

  test "magic link sender handles user struct" do
    user = create_user!()
    assert :ok = MagicLinkSender.send(user, "test-token", [])
  end

  test "magic link sender handles email string" do
    assert :ok = MagicLinkSender.send("test@example.com", "test-token", [])
  end

  test "password reset sender handles user struct" do
    user = create_user!()
    assert :ok = PasswordResetSender.send(user, "test-token", [])
  end
end
