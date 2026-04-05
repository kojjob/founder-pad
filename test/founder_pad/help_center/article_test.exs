defmodule FounderPad.HelpCenter.ArticleTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  describe "create article" do
    test "creates article with auto-generated slug" do
      admin = create_admin_user!()
      cat = create_help_category!(%{actor: admin})

      {:ok, article} =
        FounderPad.HelpCenter.Article
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "How to Set Up Billing",
            body: "Step by step guide to billing setup.",
            category_id: cat.id
          }, actor: admin)
        |> Ash.create()

      assert article.slug == "how-to-set-up-billing"
      assert article.status == :draft
    end
  end

  describe "publish article" do
    test "sets status and published_at" do
      admin = create_admin_user!()
      cat = create_help_category!(%{actor: admin})
      article = create_help_article!(cat, %{actor: admin})

      {:ok, published} =
        article
        |> Ash.Changeset.for_update(:publish, %{}, actor: admin)
        |> Ash.update()

      assert published.status == :published
      assert published.published_at
    end
  end

  describe "search" do
    test "finds articles by keyword" do
      admin = create_admin_user!()
      cat = create_help_category!(%{actor: admin})

      create_published_help_article!(cat, %{
        title: "Billing FAQ",
        body: "How to manage your billing and payments.",
        actor: admin
      })

      create_published_help_article!(cat, %{
        title: "Agent Setup",
        body: "How to configure AI agents.",
        actor: admin
      })

      results =
        FounderPad.HelpCenter.Article
        |> Ash.Query.for_read(:search, %{query: "billing"})
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).title == "Billing FAQ"
    end
  end

  describe "published read" do
    test "returns only published articles" do
      admin = create_admin_user!()
      cat = create_help_category!(%{actor: admin})
      _draft = create_help_article!(cat, %{actor: admin})
      published = create_published_help_article!(cat, %{actor: admin})

      articles =
        FounderPad.HelpCenter.Article
        |> Ash.Query.for_read(:published)
        |> Ash.read!()

      assert length(articles) == 1
      assert hd(articles).id == published.id
    end
  end
end
