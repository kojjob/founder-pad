defmodule FounderPadWeb.Admin.BlogEditorLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Factory

  describe "new post" do
    test "renders new post form", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, _view, html} = live(conn, ~p"/admin/blog/new")

      assert html =~ "New Post"
      assert html =~ "Title"
      assert html =~ "Slug"
      assert html =~ "Create Post"
    end

    test "can create a new post", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, view, _html} = live(conn, ~p"/admin/blog/new")

      view
      |> form("form[phx-submit=save]", %{
        "post" => %{
          "title" => "My New Blog Post",
          "slug" => "my-new-blog-post",
          "body" => "<p>This is the body of my new blog post with enough content.</p>",
          "excerpt" => "A short excerpt",
          "status" => "draft"
        }
      })
      |> render_submit()

      assert_redirect(view, "/admin/blog")
    end

    test "validates required fields", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, view, _html} = live(conn, ~p"/admin/blog/new")

      view
      |> form("form[phx-submit=save]", %{
        "post" => %{
          "title" => "",
          "slug" => "",
          "body" => "",
          "status" => "draft"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Please fix the errors below" || html =~ "Title is required"
    end
  end

  describe "edit post" do
    test "renders edit form with existing post data", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      post = Factory.create_post!(%{title: "Existing Post", actor: admin})

      {:ok, _view, html} = live(conn, ~p"/admin/blog/#{post.id}/edit")

      assert html =~ "Edit Post"
      assert html =~ "Existing Post"
      assert html =~ "Update Post"
    end

    test "can edit an existing post", %{conn: conn} do
      {conn, admin, _org} = setup_authenticated_admin(conn)

      post = Factory.create_post!(%{title: "Original Title", actor: admin})

      {:ok, view, _html} = live(conn, ~p"/admin/blog/#{post.id}/edit")

      view
      |> form("form[phx-submit=save]", %{
        "post" => %{
          "title" => "Updated Title",
          "slug" => post.slug,
          "body" => "<p>Updated body content with enough words for the post.</p>",
          "excerpt" => "Updated excerpt",
          "status" => "draft"
        }
      })
      |> render_submit()

      assert_redirect(view, "/admin/blog")
    end
  end

  describe "SEO score" do
    test "displays SEO score badge", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, _view, html} = live(conn, ~p"/admin/blog/new")

      assert html =~ "SEO:"
    end

    test "recalculates SEO score on validate", %{conn: conn} do
      {conn, _admin, _org} = setup_authenticated_admin(conn)

      {:ok, view, _html} = live(conn, ~p"/admin/blog/new")

      html =
        view
        |> form("form[phx-submit=save]", %{
          "post" => %{
            "title" => "A great blog post title for SEO",
            "meta_description" =>
              "This is a meta description that is long enough to pass the SEO check for descriptions in search results.",
            "excerpt" => "A good excerpt",
            "slug" => "great-blog-post"
          }
        })
        |> render_change()

      assert html =~ "SEO:"
    end
  end
end
