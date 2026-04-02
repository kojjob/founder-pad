defmodule FounderPad.Content.CategoryTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  test "creates category with auto-generated slug" do
    admin = create_admin_user!()

    {:ok, cat} =
      FounderPad.Content.Category
      |> Ash.Changeset.for_create(:create, %{
        name: "Getting Started",
        description: "Beginner guides"
      }, actor: admin)
      |> Ash.create()

    assert cat.slug == "getting-started"
  end

  test "enforces unique slug" do
    admin = create_admin_user!()
    create_category!(%{slug: "unique-slug", actor: admin})

    assert {:error, _} =
      FounderPad.Content.Category
      |> Ash.Changeset.for_create(:create, %{name: "Another", slug: "unique-slug"}, actor: admin)
      |> Ash.create()
  end
end
