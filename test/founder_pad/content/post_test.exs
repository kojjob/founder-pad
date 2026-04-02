defmodule FounderPad.Content.PostTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  describe "create post" do
    test "creates draft post with auto-generated slug" do
      admin = create_admin_user!()

      assert {:ok, post} =
        FounderPad.Content.Post
        |> Ash.Changeset.for_create(:create, %{
          title: "My First Blog Post",
          body: "<p>Hello world</p>",
          excerpt: "A test",
          author_id: admin.id
        }, actor: admin)
        |> Ash.create()

      assert post.slug == "my-first-blog-post"
      assert post.status == :draft
      assert post.reading_time_minutes == 1
    end

    test "rejects creation by non-admin" do
      user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
        FounderPad.Content.Post
        |> Ash.Changeset.for_create(:create, %{
          title: "Should Fail",
          body: "<p>No</p>",
          author_id: user.id
        }, actor: user)
        |> Ash.create()
    end
  end

  describe "publish post" do
    test "sets status to published with timestamp" do
      admin = create_admin_user!()
      post = create_post!(%{actor: admin})
      assert post.status == :draft

      {:ok, published} =
        post
        |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
        |> Ash.update()

      assert published.status == :published
      assert published.published_at
    end
  end

  describe "published read" do
    test "returns only published posts" do
      admin = create_admin_user!()
      _draft = create_post!(%{actor: admin})
      published = create_published_post!(%{actor: admin})

      posts =
        FounderPad.Content.Post
        |> Ash.Query.for_read(:published)
        |> Ash.read!()

      assert length(posts) == 1
      assert hd(posts).id == published.id
    end
  end
end
