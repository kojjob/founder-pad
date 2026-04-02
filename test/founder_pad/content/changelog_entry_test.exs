defmodule FounderPad.Content.ChangelogEntryTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  test "creates and publishes changelog entry" do
    admin = create_admin_user!()
    entry = create_changelog_entry!(%{actor: admin})
    assert entry.status == :draft

    {:ok, published} =
      entry
      |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
      |> Ash.update()

    assert published.status == :published
    assert published.published_at
  end

  test "published read returns only published entries" do
    admin = create_admin_user!()
    _draft = create_changelog_entry!(%{actor: admin})

    published_entry = create_changelog_entry!(%{actor: admin})
    published_entry
    |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
    |> Ash.update!()

    entries =
      FounderPad.Content.ChangelogEntry
      |> Ash.Query.for_read(:published)
      |> Ash.read!()

    assert length(entries) == 1
  end
end
