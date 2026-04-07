defmodule FounderPad.Content.Changes.CalculateReadingTime do
  @moduledoc "Ash change that calculates reading time in minutes from HTML body content."
  use Ash.Resource.Change

  @words_per_minute 200

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :body) do
      nil ->
        changeset

      body ->
        minutes = calculate(body)
        Ash.Changeset.force_change_attribute(changeset, :reading_time_minutes, minutes)
    end
  end

  def calculate(html) when is_binary(html) do
    word_count =
      html
      |> String.replace(~r/<[^>]+>/, " ")
      |> String.split(~r/\s+/, trim: true)
      |> length()

    max(1, div(word_count + @words_per_minute - 1, @words_per_minute))
  end

  def calculate(_), do: 1
end
