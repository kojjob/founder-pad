defmodule FounderPadWeb.Admin.SeoDashboardLive do
  use FounderPadWeb, :live_view

  alias FounderPad.Content.SeoScorer

  def mount(_params, _session, socket) do
    posts =
      FounderPad.Content.Post
      |> Ash.Query.for_read(:read, actor: socket.assigns.current_user)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!(actor: socket.assigns.current_user)

    posts_with_scores =
      Enum.map(posts, fn post ->
        %{post: post, seo: SeoScorer.score(post)}
      end)

    avg_score =
      if posts_with_scores != [] do
        scores = Enum.map(posts_with_scores, & &1.seo.score)
        div(Enum.sum(scores), length(scores))
      else
        0
      end

    {:ok,
     assign(socket,
       page_title: "SEO Dashboard — Admin",
       active_nav: :admin_seo,
       posts_with_scores: posts_with_scores,
       avg_score: avg_score
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="font-heading text-2xl font-bold text-on-surface">SEO Dashboard</h1>
          <p class="text-on-surface-variant mt-1">
            Monitor and improve your content's search visibility.
          </p>
        </div>
      </div>
      
    <!-- Overview cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="bg-white rounded-2xl border border-neutral-200/60 p-6">
          <p class="text-sm text-on-surface-variant mb-1">Total Posts</p>
          <p class="text-3xl font-heading font-bold text-on-surface">{length(@posts_with_scores)}</p>
        </div>
        <div class="bg-white rounded-2xl border border-neutral-200/60 p-6">
          <p class="text-sm text-on-surface-variant mb-1">Average SEO Score</p>
          <p class={"text-3xl font-heading font-bold #{score_color(@avg_score)}"}>{@avg_score}%</p>
        </div>
        <div class="bg-white rounded-2xl border border-neutral-200/60 p-6">
          <p class="text-sm text-on-surface-variant mb-1">Needs Improvement</p>
          <p class="text-3xl font-heading font-bold text-amber-600">
            {Enum.count(@posts_with_scores, fn ps -> ps.seo.score < 70 end)}
          </p>
        </div>
      </div>
      
    <!-- Posts SEO table -->
      <div class="bg-white rounded-2xl border border-neutral-200/60 overflow-hidden">
        <div class="px-6 py-4 border-b border-neutral-200/60">
          <h2 class="font-heading font-semibold text-on-surface">Post SEO Scores</h2>
        </div>
        <table class="w-full">
          <thead class="bg-neutral-50/50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-on-surface-variant uppercase">
                Post
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-on-surface-variant uppercase">
                Score
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-on-surface-variant uppercase">
                Issues
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-on-surface-variant uppercase">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-neutral-200/60">
            <tr :for={ps <- @posts_with_scores} class="hover:bg-neutral-50/50">
              <td class="px-6 py-4">
                <p class="font-medium text-on-surface">{ps.post.title}</p>
                <p class="text-xs text-on-surface-variant">/blog/{ps.post.slug}</p>
              </td>
              <td class="px-6 py-4">
                <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{score_badge_color(ps.seo.score)}"}>
                  {ps.seo.score}%
                </span>
              </td>
              <td class="px-6 py-4">
                <div class="flex flex-wrap gap-1">
                  <span
                    :for={{check, false} <- ps.seo.checks}
                    class="text-xs px-1.5 py-0.5 rounded bg-red-50 text-red-600"
                  >
                    {check |> Atom.to_string() |> String.replace("_", " ")}
                  </span>
                </div>
              </td>
              <td class="px-6 py-4 text-right">
                <a
                  href={"/admin/blog/#{ps.post.id}/edit"}
                  class="text-primary text-sm hover:underline"
                >
                  Edit
                </a>
              </td>
            </tr>
          </tbody>
        </table>
        <div :if={@posts_with_scores == []} class="px-6 py-12 text-center text-on-surface-variant">
          No posts yet. Create your first post to see SEO analysis.
        </div>
      </div>
    </div>
    """
  end

  defp score_color(score) when score >= 80, do: "text-green-600"
  defp score_color(score) when score >= 50, do: "text-amber-600"
  defp score_color(_), do: "text-red-600"

  defp score_badge_color(score) when score >= 80, do: "bg-green-100 text-green-700"
  defp score_badge_color(score) when score >= 50, do: "bg-amber-100 text-amber-700"
  defp score_badge_color(_), do: "bg-red-100 text-red-700"
end
