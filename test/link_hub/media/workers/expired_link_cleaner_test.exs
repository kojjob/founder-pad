defmodule LinkHub.Media.Workers.ExpiredLinkCleanerTest do
  use LinkHub.DataCase, async: true
  use Oban.Testing, repo: LinkHub.Repo

  alias LinkHub.Factory
  alias LinkHub.Media.Workers.ExpiredLinkCleaner

  setup do
    workspace = Factory.create_workspace!()
    user = Factory.create_user!()
    Factory.create_membership!(user, workspace)
    stored_file = Factory.create_stored_file!(workspace, user)
    %{workspace: workspace, user: user, stored_file: stored_file}
  end

  describe "perform/1" do
    test "deactivates expired links", %{stored_file: stored_file, user: user} do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)

      link =
        LinkHub.Media.ShareLink
        |> Ash.Changeset.for_create(:create, %{
          stored_file_id: stored_file.id,
          created_by_id: user.id,
          expires_at: past
        })
        |> Ash.create!()

      assert link.active == true

      assert :ok = perform_job(ExpiredLinkCleaner, %{})

      updated = Ash.get!(LinkHub.Media.ShareLink, link.id)
      assert updated.active == false
    end

    test "does not deactivate non-expired links", %{stored_file: stored_file, user: user} do
      future = DateTime.add(DateTime.utc_now(), 7200, :second)

      link =
        LinkHub.Media.ShareLink
        |> Ash.Changeset.for_create(:create, %{
          stored_file_id: stored_file.id,
          created_by_id: user.id,
          expires_at: future
        })
        |> Ash.create!()

      assert :ok = perform_job(ExpiredLinkCleaner, %{})

      updated = Ash.get!(LinkHub.Media.ShareLink, link.id)
      assert updated.active == true
    end

    test "does not deactivate links without expiry", %{stored_file: stored_file, user: user} do
      link =
        LinkHub.Media.ShareLink
        |> Ash.Changeset.for_create(:create, %{
          stored_file_id: stored_file.id,
          created_by_id: user.id
        })
        |> Ash.create!()

      assert :ok = perform_job(ExpiredLinkCleaner, %{})

      updated = Ash.get!(LinkHub.Media.ShareLink, link.id)
      assert updated.active == true
    end

    test "succeeds with no expired links" do
      assert :ok = perform_job(ExpiredLinkCleaner, %{})
    end
  end
end
