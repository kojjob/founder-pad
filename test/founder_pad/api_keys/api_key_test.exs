defmodule FounderPad.ApiKeys.ApiKeyTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  describe "create API key" do
    test "generates key with prefix and hash" do
      {user, org} = setup_user_with_org()

      {:ok, key} =
        FounderPad.ApiKeys.ApiKey
        |> Ash.Changeset.for_create(:create, %{
          name: "My API Key",
          scopes: [:read, :write],
          organisation_id: org.id,
          created_by_id: user.id
        })
        |> Ash.create()

      assert key.key_prefix =~ ~r/^fp_/
      assert key.key_hash
      assert key.scopes == [:read, :write]
      assert key.__raw_key__
    end
  end

  describe "revoke API key" do
    test "sets revoked_at timestamp" do
      {user, org} = setup_user_with_org()
      key = create_api_key!(org, user)
      assert is_nil(key.revoked_at)

      {:ok, revoked} =
        key
        |> Ash.Changeset.for_update(:revoke, %{})
        |> Ash.update()

      assert revoked.revoked_at
    end
  end

  describe "find by hash" do
    test "finds active key by hash" do
      {user, org} = setup_user_with_org()
      key = create_api_key!(org, user)

      found =
        FounderPad.ApiKeys.ApiKey
        |> Ash.Query.for_read(:by_key_hash, %{hash: key.key_hash})
        |> Ash.read!()

      assert length(found) == 1
      assert hd(found).id == key.id
    end

    test "does not find revoked key" do
      {user, org} = setup_user_with_org()
      key = create_api_key!(org, user)
      key |> Ash.Changeset.for_update(:revoke, %{}) |> Ash.update!()

      found =
        FounderPad.ApiKeys.ApiKey
        |> Ash.Query.for_read(:by_key_hash, %{hash: key.key_hash})
        |> Ash.read!()

      assert found == []
    end
  end

  defp setup_user_with_org do
    user = create_user!()
    org = create_organisation!()
    create_membership!(user, org, :owner)
    {user, org}
  end
end
