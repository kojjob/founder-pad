defmodule FounderPad.Content.Changes.GenerateSlug do
  @moduledoc "Ash change that auto-generates a URL slug from a title or name attribute."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    source_text =
      Ash.Changeset.get_attribute(changeset, :title) ||
        Ash.Changeset.get_attribute(changeset, :name)

    case source_text do
      nil ->
        changeset

      text ->
        slug = Ash.Changeset.get_attribute(changeset, :slug)

        if is_nil(slug) or slug == "" do
          Ash.Changeset.force_change_attribute(changeset, :slug, slugify(text))
        else
          changeset
        end
    end
  end

  def slugify(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.trim()
    |> String.replace(~r/[\s-]+/, "-")
    |> String.trim("-")
  end

  def slugify(_), do: ""
end
