defmodule FounderPad.Accounts.SendersTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  test "magic link sender handles user struct" do
    user = create_user!()
    assert :ok = FounderPad.Accounts.Senders.MagicLinkSender.send(user, "test-token", [])
  end

  test "magic link sender handles email string" do
    assert :ok = FounderPad.Accounts.Senders.MagicLinkSender.send("test@example.com", "test-token", [])
  end

  test "password reset sender handles user struct" do
    user = create_user!()
    assert :ok = FounderPad.Accounts.Senders.PasswordResetSender.send(user, "test-token", [])
  end
end
