defmodule FounderPad.Content.SeoScorer do
  @moduledoc "Calculates an SEO completeness score for a blog post."

  def score(post) do
    checks = [
      {:title_length, check_title_length(post)},
      {:meta_description, check_meta_description(post)},
      {:has_excerpt, check_excerpt(post)},
      {:has_featured_image, not is_nil(access(post, :featured_image_url))},
      {:has_canonical_url, not is_nil(access(post, :canonical_url))},
      {:slug_is_clean, check_slug(post)},
      {:body_length, check_body_length(post)},
      {:has_og_image, not is_nil(access(post, :og_image_url))}
    ]

    passed = Enum.count(checks, fn {_, pass} -> pass end)
    %{score: round(passed / length(checks) * 100), checks: checks}
  end

  defp check_title_length(post) do
    title = access(post, :title) || ""
    len = String.length(title)
    len >= 20 and len <= 70
  end

  defp check_meta_description(post) do
    desc = access(post, :meta_description)
    not is_nil(desc) and String.length(desc) >= 50 and String.length(desc) <= 160
  end

  defp check_excerpt(post) do
    excerpt = access(post, :excerpt)
    not is_nil(excerpt) and excerpt != ""
  end

  defp check_slug(post) do
    slug = access(post, :slug) || ""
    Regex.match?(~r/^[a-z0-9\-]+$/, slug)
  end

  defp check_body_length(post) do
    body = access(post, :body) || ""

    word_count =
      body |> String.replace(~r/<[^>]+>/, " ") |> String.split(~r/\s+/, trim: true) |> length()

    word_count >= 50
  end

  defp access(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
