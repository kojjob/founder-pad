defmodule FounderPad.Accounts.UserTotpTest do
  use FounderPad.DataCase, async: true

  alias FounderPad.Accounts.UserTotp
  import FounderPad.Factory
  import Bitwise

  describe "generate_secret/0" do
    test "generates a base32-encoded string" do
      secret = UserTotp.generate_secret()

      assert is_binary(secret)
      assert byte_size(secret) > 0
      # Should be decodable as base32
      assert {:ok, _} = Base.decode32(secret, padding: false)
    end

    test "generates unique secrets" do
      secrets = Enum.map(1..10, fn _ -> UserTotp.generate_secret() end)
      assert length(Enum.uniq(secrets)) == 10
    end
  end

  describe "generate_backup_codes/0" do
    test "generates 8 backup codes" do
      codes = UserTotp.generate_backup_codes()

      assert length(codes) == 8
      assert Enum.all?(codes, &is_binary/1)
    end

    test "generates hex-encoded codes" do
      codes = UserTotp.generate_backup_codes()

      Enum.each(codes, fn code ->
        assert String.match?(code, ~r/^[0-9a-f]+$/)
      end)
    end

    test "generates unique codes" do
      codes = UserTotp.generate_backup_codes()
      assert length(Enum.uniq(codes)) == 8
    end
  end

  describe "verify_code/2" do
    test "verifies a valid TOTP code" do
      secret = UserTotp.generate_secret()
      # Generate the current valid code
      time = System.system_time(:second)
      counter = div(time, 30)
      code = compute_test_totp(secret, counter)

      assert UserTotp.verify_code(secret, code) == true
    end

    test "rejects an invalid TOTP code" do
      secret = UserTotp.generate_secret()

      assert UserTotp.verify_code(secret, "000000") == false
    end

    test "accepts code from previous time window" do
      secret = UserTotp.generate_secret()
      time = System.system_time(:second)
      counter = div(time, 30)
      # Previous window
      code = compute_test_totp(secret, counter - 1)

      assert UserTotp.verify_code(secret, code) == true
    end

    test "accepts code from next time window" do
      secret = UserTotp.generate_secret()
      time = System.system_time(:second)
      counter = div(time, 30)
      # Next window
      code = compute_test_totp(secret, counter + 1)

      assert UserTotp.verify_code(secret, code) == true
    end
  end

  describe "create action" do
    test "creates a TOTP record for a user with auto-generated secret and backup codes" do
      user = create_user!()

      assert {:ok, totp} =
               UserTotp
               |> Ash.Changeset.for_create(:create, %{user_id: user.id})
               |> Ash.create()

      assert totp.user_id == user.id
      assert totp.secret != nil
      assert totp.enabled == false
      assert length(totp.backup_codes) == 8
    end

    test "enforces unique user constraint" do
      user = create_user!()

      UserTotp
      |> Ash.Changeset.for_create(:create, %{user_id: user.id})
      |> Ash.create!()

      assert {:error, _} =
               UserTotp
               |> Ash.Changeset.for_create(:create, %{user_id: user.id})
               |> Ash.create()
    end
  end

  describe "enable/disable actions" do
    test "enable sets enabled to true" do
      user = create_user!()

      totp =
        UserTotp
        |> Ash.Changeset.for_create(:create, %{user_id: user.id})
        |> Ash.create!()

      assert totp.enabled == false

      {:ok, updated} =
        totp
        |> Ash.Changeset.for_update(:enable, %{})
        |> Ash.update()

      assert updated.enabled == true
    end

    test "disable sets enabled to false" do
      user = create_user!()

      totp =
        UserTotp
        |> Ash.Changeset.for_create(:create, %{user_id: user.id})
        |> Ash.create!()

      # Enable first
      totp =
        totp
        |> Ash.Changeset.for_update(:enable, %{})
        |> Ash.update!()

      assert totp.enabled == true

      # Now disable
      {:ok, updated} =
        totp
        |> Ash.Changeset.for_update(:disable, %{})
        |> Ash.update()

      assert updated.enabled == false
    end
  end

  describe "by_user action" do
    test "finds TOTP by user_id" do
      user = create_user!()

      UserTotp
      |> Ash.Changeset.for_create(:create, %{user_id: user.id})
      |> Ash.create!()

      assert {:ok, [totp]} =
               UserTotp
               |> Ash.Query.for_read(:by_user, %{user_id: user.id})
               |> Ash.read()

      assert totp.user_id == user.id
    end

    test "returns empty list for user without TOTP" do
      user = create_user!()

      assert {:ok, []} =
               UserTotp
               |> Ash.Query.for_read(:by_user, %{user_id: user.id})
               |> Ash.read()
    end
  end

  # Helper to compute TOTP for testing (mirrors the resource implementation)
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
