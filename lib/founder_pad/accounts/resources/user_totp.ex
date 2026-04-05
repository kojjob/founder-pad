defmodule FounderPad.Accounts.UserTotp do
  import Bitwise

  use Ash.Resource,
    domain: FounderPad.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("user_totps")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :secret, :string do
      allow_nil?(false)
      sensitive?(true)
    end

    attribute :enabled, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
    end

    attribute :backup_codes, {:array, :string} do
      default([])
      sensitive?(true)
    end

    attribute :last_used_at, :utc_datetime_usec do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :user, FounderPad.Accounts.User do
      allow_nil?(false)
      attribute_type(:uuid)
    end
  end

  identities do
    identity(:unique_user, [:user_id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:user_id])

      change(fn changeset, _context ->
        secret = generate_secret()
        backup = generate_backup_codes()

        changeset
        |> Ash.Changeset.force_change_attribute(:secret, secret)
        |> Ash.Changeset.force_change_attribute(:backup_codes, backup)
      end)
    end

    update :enable do
      accept([])
      change(set_attribute(:enabled, true))
    end

    update :disable do
      accept([])
      change(set_attribute(:enabled, false))
    end

    read :by_user do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id)))
    end
  end

  @doc "Generate a 20-byte base32-encoded TOTP secret."
  def generate_secret do
    :crypto.strong_rand_bytes(20) |> Base.encode32(padding: false)
  end

  @doc "Generate 8 backup codes."
  def generate_backup_codes do
    Enum.map(1..8, fn _ ->
      :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    end)
  end

  @doc "Verify a TOTP code against a secret."
  def verify_code(secret, code) do
    time = System.system_time(:second)
    counter = div(time, 30)

    Enum.any?(-1..1, fn offset ->
      expected = compute_totp(secret, counter + offset)
      expected == String.pad_leading(code, 6, "0")
    end)
  end

  defp compute_totp(secret, counter) do
    key = Base.decode32!(secret, padding: false)
    msg = <<counter::unsigned-big-integer-size(64)>>
    hmac = :crypto.mac(:hmac, :sha, key, msg)
    offset = :binary.at(hmac, byte_size(hmac) - 1) &&& 0x0F
    <<_::binary-size(offset), code::unsigned-big-integer-size(32), _::binary>> = hmac
    otp = rem(code &&& 0x7FFFFFFF, 1_000_000)
    String.pad_leading(Integer.to_string(otp), 6, "0")
  end
end
