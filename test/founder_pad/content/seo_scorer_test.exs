defmodule FounderPad.Content.SeoScorerTest do
  use ExUnit.Case, async: true

  alias FounderPad.Content.SeoScorer

  describe "score/1" do
    test "perfect score for well-optimized post" do
      post = %{
        title: "A Perfect Title That Is Good Length",
        meta_description: String.duplicate("a", 130),
        excerpt: "Has an excerpt",
        featured_image_url: "/uploads/blog/image.jpg",
        canonical_url: "https://example.com/blog/post",
        slug: "perfect-post",
        body: String.duplicate("word ", 100),
        og_image_url: "/uploads/blog/og.jpg"
      }

      result = SeoScorer.score(post)
      assert result.score == 100
      assert Enum.all?(result.checks, fn {_name, pass} -> pass end)
    end

    test "low score for empty post" do
      post = %{
        title: "Hi",
        meta_description: nil,
        excerpt: nil,
        featured_image_url: nil,
        canonical_url: nil,
        slug: "hi",
        body: nil,
        og_image_url: nil
      }

      result = SeoScorer.score(post)
      assert result.score < 50
    end
  end
end
