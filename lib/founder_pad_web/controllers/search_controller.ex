defmodule FounderPadWeb.SearchController do
  @moduledoc """
  API controller for global search across pages, blog posts, and help articles.
  Powers the Cmd+K command palette.
  """
  use FounderPadWeb, :controller

  require Ash.Query

  @pages [
    %{title: "Dashboard", url: "/dashboard", icon: "dashboard"},
    %{title: "Agents", url: "/agents", icon: "smart_toy"},
    %{title: "Billing", url: "/billing", icon: "credit_card"},
    %{title: "Team", url: "/team", icon: "group"},
    %{title: "Settings", url: "/settings", icon: "settings"},
    %{title: "API Keys", url: "/api-keys", icon: "key"},
    %{title: "Activity", url: "/activity", icon: "history"},
    %{title: "Workspaces", url: "/workspaces", icon: "corporate_fare"}
  ]

  def search(conn, %{"q" => query}) when byte_size(query) >= 2 do
    results = search_all(query)
    json(conn, %{results: results})
  end

  def search(conn, _params) do
    json(conn, %{results: []})
  end

  defp search_all(query) do
    pages = search_pages(query)
    blog = search_blog(query)
    help = search_help(query)

    pages ++ blog ++ help
  end

  defp search_pages(query) do
    query_down = String.downcase(query)

    @pages
    |> Enum.filter(fn p -> String.contains?(String.downcase(p.title), query_down) end)
    |> Enum.map(fn p -> Map.put(p, :type, "page") end)
  end

  defp search_blog(query) do
    like_query = "%#{query}%"

    FounderPad.Content.Post
    |> Ash.Query.for_read(:published)
    |> Ash.Query.filter(fragment("? ILIKE ?", title, ^like_query))
    |> Ash.Query.limit(5)
    |> Ash.read!()
    |> Enum.map(fn p ->
      %{
        type: "blog",
        title: p.title,
        description: p.excerpt,
        url: "/blog/#{p.slug}",
        icon: "article"
      }
    end)
  rescue
    _ -> []
  end

  defp search_help(query) do
    FounderPad.HelpCenter.Article
    |> Ash.Query.for_read(:search, %{query: query})
    |> Ash.Query.limit(5)
    |> Ash.read!()
    |> Enum.map(fn a ->
      %{
        type: "help",
        title: a.title,
        description: a.excerpt,
        url: "/help",
        icon: "help"
      }
    end)
  rescue
    _ -> []
  end
end
