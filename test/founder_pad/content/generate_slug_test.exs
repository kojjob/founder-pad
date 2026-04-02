defmodule FounderPad.Content.Changes.GenerateSlugTest do
  use FounderPad.DataCase, async: true

  alias FounderPad.Content.Changes.GenerateSlug

  describe "slugify/1" do
    test "converts title to slug" do
      assert GenerateSlug.slugify("Hello World") == "hello-world"
    end

    test "handles special characters" do
      assert GenerateSlug.slugify("What's New in v2.0?") == "whats-new-in-v20"
    end

    test "handles multiple spaces and dashes" do
      assert GenerateSlug.slugify("  Multiple   Spaces  ") == "multiple-spaces"
    end

    test "handles unicode" do
      assert GenerateSlug.slugify("Cafe\u0301 & Re\u0301sume\u0301") == "cafe-resume"
    end

    test "returns empty string for non-binary input" do
      assert GenerateSlug.slugify(nil) == ""
      assert GenerateSlug.slugify(123) == ""
    end
  end
end
