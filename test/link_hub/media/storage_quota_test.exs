defmodule LinkHub.Media.StorageQuotaTest do
  use LinkHub.DataCase, async: true

  alias LinkHub.Factory

  require Ash.Query

  defp create_quota!(workspace, attrs \\ %{}) do
    default = %{
      workspace_id: workspace.id,
      used_bytes: 0,
      quota_bytes: 10_000_000,
      file_count: 0
    }

    params = Map.merge(default, Map.new(attrs))

    LinkHub.Media.StorageQuota
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  setup do
    workspace = Factory.create_workspace!()
    %{workspace: workspace}
  end

  describe "create action" do
    test "creates a quota for a workspace with defaults", %{workspace: workspace} do
      quota = create_quota!(workspace)

      assert quota.workspace_id == workspace.id
      assert quota.used_bytes == 0
      assert quota.file_count == 0
      assert quota.quota_bytes == 10_000_000
    end

    test "creates a quota with custom values", %{workspace: workspace} do
      quota = create_quota!(workspace, %{used_bytes: 500, quota_bytes: 5_000_000, file_count: 3})

      assert quota.used_bytes == 500
      assert quota.quota_bytes == 5_000_000
      assert quota.file_count == 3
    end

    test "creates a quota with nil quota_bytes (unlimited)", %{workspace: workspace} do
      quota = create_quota!(workspace, %{quota_bytes: nil})

      assert is_nil(quota.quota_bytes)
    end

    test "requires workspace_id" do
      assert_raise Ash.Error.Invalid, fn ->
        LinkHub.Media.StorageQuota
        |> Ash.Changeset.for_create(:create, %{})
        |> Ash.create!()
      end
    end
  end

  describe "record_upload action" do
    test "increments used_bytes and file_count", %{workspace: workspace} do
      quota = create_quota!(workspace, %{used_bytes: 1000, file_count: 2})

      updated =
        quota
        |> Ash.Changeset.for_update(:record_upload, %{file_size: 500})
        |> Ash.update!()

      assert updated.used_bytes == 1500
      assert updated.file_count == 3
    end

    test "multiple uploads accumulate correctly", %{workspace: workspace} do
      quota = create_quota!(workspace)

      quota =
        quota
        |> Ash.Changeset.for_update(:record_upload, %{file_size: 1000})
        |> Ash.update!()

      quota =
        quota
        |> Ash.Changeset.for_update(:record_upload, %{file_size: 2500})
        |> Ash.update!()

      assert quota.used_bytes == 3500
      assert quota.file_count == 2
    end
  end

  describe "record_deletion action" do
    test "decrements used_bytes and file_count", %{workspace: workspace} do
      quota = create_quota!(workspace, %{used_bytes: 5000, file_count: 5})

      updated =
        quota
        |> Ash.Changeset.for_update(:record_deletion, %{file_size: 1000})
        |> Ash.update!()

      assert updated.used_bytes == 4000
      assert updated.file_count == 4
    end

    test "floors used_bytes at 0 when file_size exceeds used_bytes", %{workspace: workspace} do
      quota = create_quota!(workspace, %{used_bytes: 500, file_count: 1})

      updated =
        quota
        |> Ash.Changeset.for_update(:record_deletion, %{file_size: 9999})
        |> Ash.update!()

      assert updated.used_bytes == 0
    end

    test "floors file_count at 0 when already zero", %{workspace: workspace} do
      quota = create_quota!(workspace, %{used_bytes: 1000, file_count: 0})

      updated =
        quota
        |> Ash.Changeset.for_update(:record_deletion, %{file_size: 500})
        |> Ash.update!()

      assert updated.file_count == 0
      assert updated.used_bytes == 500
    end
  end

  describe "set_quota action" do
    test "updates quota_bytes", %{workspace: workspace} do
      quota = create_quota!(workspace, %{quota_bytes: 10_000_000})

      updated =
        quota
        |> Ash.Changeset.for_update(:set_quota, %{quota_bytes: 50_000_000})
        |> Ash.update!()

      assert updated.quota_bytes == 50_000_000
    end

    test "sets quota_bytes to nil for unlimited", %{workspace: workspace} do
      quota = create_quota!(workspace, %{quota_bytes: 10_000_000})

      updated =
        quota
        |> Ash.Changeset.for_update(:set_quota, %{quota_bytes: nil})
        |> Ash.update!()

      assert is_nil(updated.quota_bytes)
    end
  end

  describe "get_by_workspace action" do
    test "returns the correct quota for a workspace", %{workspace: workspace} do
      created = create_quota!(workspace)

      [found] =
        LinkHub.Media.StorageQuota
        |> Ash.Query.for_read(:get_by_workspace, %{workspace_id: workspace.id})
        |> Ash.read!()

      assert found.id == created.id
      assert found.workspace_id == workspace.id
    end

    test "returns empty list for workspace without quota" do
      other_workspace = Factory.create_workspace!()

      result =
        LinkHub.Media.StorageQuota
        |> Ash.Query.for_read(:get_by_workspace, %{workspace_id: other_workspace.id})
        |> Ash.read!()

      assert result == []
    end
  end

  describe "bytes_remaining calculation" do
    test "returns remaining bytes when quota is set", %{workspace: workspace} do
      quota =
        create_quota!(workspace, %{used_bytes: 3_000_000, quota_bytes: 10_000_000})
        |> Ash.load!(:bytes_remaining)

      assert quota.bytes_remaining == 7_000_000
    end

    test "returns 0 when usage exceeds quota", %{workspace: workspace} do
      quota =
        create_quota!(workspace, %{used_bytes: 15_000_000, quota_bytes: 10_000_000})
        |> Ash.load!(:bytes_remaining)

      assert quota.bytes_remaining == 0
    end

    test "returns nil when quota_bytes is nil (unlimited)", %{workspace: workspace} do
      quota =
        create_quota!(workspace, %{used_bytes: 5_000_000, quota_bytes: nil})
        |> Ash.load!(:bytes_remaining)

      assert is_nil(quota.bytes_remaining)
    end
  end

  describe "usage_percentage calculation" do
    test "returns correct percentage", %{workspace: workspace} do
      quota =
        create_quota!(workspace, %{used_bytes: 5_000_000, quota_bytes: 10_000_000})
        |> Ash.load!(:usage_percentage)

      assert quota.usage_percentage == 50
    end

    test "returns 0 when quota_bytes is nil (unlimited)", %{workspace: workspace} do
      quota =
        create_quota!(workspace, %{quota_bytes: nil, used_bytes: 5_000_000})
        |> Ash.load!(:usage_percentage)

      assert quota.usage_percentage == 0
    end

    test "returns 0 when quota_bytes is 0", %{workspace: workspace} do
      quota =
        create_quota!(workspace, %{quota_bytes: 0, used_bytes: 0})
        |> Ash.load!(:usage_percentage)

      assert quota.usage_percentage == 0
    end

    test "returns over 100 when usage exceeds quota", %{workspace: workspace} do
      quota =
        create_quota!(workspace, %{used_bytes: 15_000_000, quota_bytes: 10_000_000})
        |> Ash.load!(:usage_percentage)

      assert quota.usage_percentage == 150
    end
  end

  describe "unique workspace identity" do
    test "prevents duplicate quotas for the same workspace", %{workspace: workspace} do
      create_quota!(workspace)

      assert_raise Ash.Error.Invalid, fn ->
        create_quota!(workspace)
      end
    end
  end
end
