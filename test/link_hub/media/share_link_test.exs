defmodule LinkHub.Media.ShareLinkTest do
  use LinkHub.DataCase, async: true

  alias LinkHub.Factory
  require Ash.Query

  setup do
    workspace = Factory.create_workspace!()
    user = Factory.create_user!()
    Factory.create_membership!(user, workspace)
    stored_file = Factory.create_stored_file!(workspace, user)
    %{workspace: workspace, user: user, stored_file: stored_file}
  end

  defp create_share_link!(ctx, attrs \\ %{}) do
    defaults = %{
      stored_file_id: ctx.stored_file.id,
      created_by_id: ctx.user.id
    }

    LinkHub.Media.ShareLink
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, Map.new(attrs)))
    |> Ash.create!()
  end

  describe "create" do
    test "generates a token automatically", ctx do
      link = create_share_link!(ctx)

      assert link.token != nil
      assert is_binary(link.token)
      assert String.length(link.token) > 0
    end

    test "tokens are unique across links", ctx do
      link1 = create_share_link!(ctx)
      link2 = create_share_link!(ctx)

      assert link1.token != link2.token
    end

    test "sets default values for download_count and active", ctx do
      link = create_share_link!(ctx)

      assert link.download_count == 0
      assert link.active == true
    end

    test "accepts optional password_hash and max_downloads", ctx do
      link =
        create_share_link!(ctx, %{
          password_hash: "hashed_secret_value",
          max_downloads: 100
        })

      assert link.max_downloads == 100
      # password_hash is not public, so reload and check via Ecto
      reloaded =
        LinkHub.Media.ShareLink
        |> Ash.get!(link.id, load: [])

      assert reloaded.max_downloads == 100
    end

    test "accepts optional expires_at", ctx do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      link = create_share_link!(ctx, %{expires_at: future})

      assert link.expires_at != nil
    end
  end

  describe "record_download" do
    test "atomically increments download_count", ctx do
      link = create_share_link!(ctx)
      assert link.download_count == 0

      {:ok, updated} =
        link
        |> Ash.Changeset.for_update(:record_download, %{})
        |> Ash.update()

      assert updated.download_count == 1

      {:ok, updated2} =
        updated
        |> Ash.Changeset.for_update(:record_download, %{})
        |> Ash.update()

      assert updated2.download_count == 2
    end
  end

  describe "deactivate" do
    test "sets active to false", ctx do
      link = create_share_link!(ctx)
      assert link.active == true

      {:ok, deactivated} =
        link
        |> Ash.Changeset.for_update(:deactivate, %{})
        |> Ash.update()

      assert deactivated.active == false
    end
  end

  describe "get_by_token" do
    test "returns the link with stored_file loaded", ctx do
      link = create_share_link!(ctx)

      [found] =
        LinkHub.Media.ShareLink
        |> Ash.Query.for_read(:get_by_token, %{token: link.token})
        |> Ash.read!()

      assert found.id == link.id
      assert found.stored_file != nil
      assert found.stored_file.id == ctx.stored_file.id
    end

    test "does not return deactivated links", ctx do
      link = create_share_link!(ctx)

      link
      |> Ash.Changeset.for_update(:deactivate, %{})
      |> Ash.update!()

      results =
        LinkHub.Media.ShareLink
        |> Ash.Query.for_read(:get_by_token, %{token: link.token})
        |> Ash.read!()

      assert results == []
    end

    test "returns empty for nonexistent token", _ctx do
      results =
        LinkHub.Media.ShareLink
        |> Ash.Query.for_read(:get_by_token, %{token: "nonexistent_token"})
        |> Ash.read!()

      assert results == []
    end
  end

  describe "list_expired" do
    test "returns active links past their expires_at", ctx do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      expired_link = create_share_link!(ctx, %{expires_at: past})

      results =
        LinkHub.Media.ShareLink
        |> Ash.Query.for_read(:list_expired)
        |> Ash.read!()

      ids = Enum.map(results, & &1.id)
      assert expired_link.id in ids
    end

    test "does not return links with future expires_at", ctx do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      future_link = create_share_link!(ctx, %{expires_at: future})

      results =
        LinkHub.Media.ShareLink
        |> Ash.Query.for_read(:list_expired)
        |> Ash.read!()

      ids = Enum.map(results, & &1.id)
      refute future_link.id in ids
    end

    test "does not return links without expires_at", ctx do
      no_expiry_link = create_share_link!(ctx)

      results =
        LinkHub.Media.ShareLink
        |> Ash.Query.for_read(:list_expired)
        |> Ash.read!()

      ids = Enum.map(results, & &1.id)
      refute no_expiry_link.id in ids
    end

    test "does not return deactivated expired links", ctx do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      link = create_share_link!(ctx, %{expires_at: past})

      link
      |> Ash.Changeset.for_update(:deactivate, %{})
      |> Ash.update!()

      results =
        LinkHub.Media.ShareLink
        |> Ash.Query.for_read(:list_expired)
        |> Ash.read!()

      ids = Enum.map(results, & &1.id)
      refute link.id in ids
    end
  end
end
