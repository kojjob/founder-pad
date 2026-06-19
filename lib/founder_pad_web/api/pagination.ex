defmodule FounderPadWeb.Api.Pagination do
  @moduledoc "Shared limit/offset + status-filter helpers for `/v1` collection endpoints."
  require Ash.Query

  @default_limit 20
  @max_limit 100

  # Known statuses across verification resources — interned at compile time so the
  # filter never needs String.to_existing_atom on user input.
  @statuses ~w(pending processing verified failed requires_review cancelled expired
               clear possible_match confirmed_match)a

  @doc "Parse `limit` (1..100, default 20) and `offset` (>= 0) from string params."
  def parse(params) do
    {clamp(to_int(Map.get(params, "limit"), @default_limit), 1, @max_limit),
     max(to_int(Map.get(params, "offset"), 0), 0)}
  end

  @doc "Apply a `status` filter to the query when a known status is supplied."
  def maybe_filter_status(query, %{"status" => status}) when is_binary(status) do
    case Enum.find(@statuses, &(Atom.to_string(&1) == status)) do
      nil -> query
      atom -> Ash.Query.filter(query, status == ^atom)
    end
  end

  def maybe_filter_status(query, _params), do: query

  defp to_int(nil, default), do: default

  defp to_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> n
      :error -> default
    end
  end

  defp to_int(value, _default) when is_integer(value), do: value

  defp clamp(n, lo, hi), do: n |> max(lo) |> min(hi)
end
