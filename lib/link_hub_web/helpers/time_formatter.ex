defmodule LinkHubWeb.Helpers.TimeFormatter do
  @moduledoc "Shared time formatting helpers for LiveView modules."

  @doc """
  Formats a DateTime as a human-readable relative time string.

  Returns "Just now" for < 60s, "Xm ago" / "Xh ago" for shorter intervals,
  "Yesterday" for the previous day, and a "Mon DD" date for anything older.
  """
  def time_ago(nil), do: "—"

  def time_ago(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3_600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3_600)}h ago"
      diff < 172_800 -> "Yesterday"
      true -> Calendar.strftime(dt, "%b %d")
    end
  end
end
