defmodule FounderPadWeb.ReviewQueueLive do
  @moduledoc """
  Compliance officer view: the manual review queue. Officers approve, reject or
  request more info on cases. Every decision requires a reason and writes an
  immutable audit event.
  """
  use FounderPadWeb, :live_view

  require Ash.Query

  alias FounderPad.Compliance.ReviewCase

  @decisions %{
    "approve" => {:approve, :approved},
    "reject" => {:reject, :rejected},
    "request_more_info" => {:request_more_info, :more_info_requested}
  }

  def mount(_params, _session, socket) do
    org = current_org(socket.assigns.current_user)

    {:ok,
     assign(socket,
       page_title: "Review Queue",
       active_nav: :reviews,
       org: org,
       cases: load_cases(org)
     )}
  end

  def handle_event("decide", %{"review_id" => id, "decision" => decision} = params, socket) do
    reason = Map.get(params, "decision_reason", "")
    {action, status} = Map.fetch!(@decisions, decision)

    with {:ok, review} <- fetch_case(id, socket.assigns.org),
         {:ok, _updated} <-
           review
           |> Ash.Changeset.for_update(action, %{decision_reason: reason})
           |> Ash.update() do
      audit_decision(socket, review, status)

      {:noreply,
       socket
       |> put_flash(:info, "Case #{status}.")
       |> assign(cases: load_cases(socket.assigns.org))}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "A decision reason is required.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-4xl mx-auto">
      <header>
        <div class="flex items-center gap-2 text-xs font-mono text-on-surface-variant/60 uppercase tracking-widest mb-2">
          <span class="material-symbols-outlined text-sm text-primary">gavel</span> Compliance
        </div>
        <h1 class="text-4xl font-extrabold font-headline tracking-tight">Review Queue</h1>
        <p class="text-on-surface-variant mt-1">
          Cases that need a human decision. Every decision is reasoned and audited.
        </p>
      </header>

      <div :if={@cases == []} class="text-center py-16">
        <span class="material-symbols-outlined text-6xl text-on-surface-variant/30 mb-4 block">
          inbox
        </span>
        <h3 class="text-xl font-bold font-headline mb-2">Queue is clear</h3>
        <p class="text-on-surface-variant">No cases are waiting for review.</p>
      </div>

      <div :for={c <- @cases} class="bg-surface-container rounded-lg p-5 space-y-4">
        <div class="flex items-center justify-between">
          <div>
            <p class="font-mono text-sm">{c.subject_type}</p>
            <p class="font-mono text-xs text-on-surface-variant">{c.subject_id}</p>
          </div>
          <span class={["px-2 py-0.5 rounded text-xs font-bold", priority_badge(c.priority)]}>
            {c.priority}
          </span>
        </div>

        <form id={"decision-#{c.id}"} phx-submit="decide" class="space-y-3">
          <input type="hidden" name="review_id" value={c.id} />
          <input type="hidden" name="decision" value="approve" />
          <textarea
            name="decision_reason"
            rows="2"
            placeholder="Decision reason (required)…"
            class="w-full text-sm bg-surface-container-high rounded-lg border-0 px-3 py-2 text-on-surface placeholder-on-surface-variant/50 focus:ring-1 focus:ring-primary"
          ></textarea>
          <div class="flex gap-2">
            <button
              type="submit"
              name="decision"
              value="approve"
              class="px-4 py-2 text-sm font-medium rounded-lg bg-primary text-on-primary hover:opacity-90"
            >
              Approve
            </button>
            <button
              type="submit"
              name="decision"
              value="reject"
              class="px-4 py-2 text-sm font-medium rounded-lg bg-error text-on-error hover:opacity-90"
            >
              Reject
            </button>
            <button
              type="submit"
              name="decision"
              value="request_more_info"
              class="px-4 py-2 text-sm font-medium rounded-lg bg-surface-container-high text-on-surface hover:bg-surface-container-highest"
            >
              Request more info
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp load_cases(nil), do: []
  defp load_cases(org), do: FounderPad.Compliance.list_open_review_cases!(org.id)

  defp fetch_case(id, org) do
    case Ash.get(ReviewCase, id, authorize?: false) do
      {:ok, %{organisation_id: org_id} = review} when org_id == org.id -> {:ok, review}
      _ -> :error
    end
  end

  defp audit_decision(socket, review, status) do
    FounderPad.Audit.log(
      :update,
      "ReviewCase",
      review.id,
      socket.assigns.current_user.id,
      review.organisation_id, metadata: %{event: "review_case.#{status}", actor_type: "user"})
  end

  defp current_org(user) do
    FounderPad.Accounts.Membership
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.load([:organisation])
    |> Ash.read!()
    |> case do
      [m | _] -> m.organisation
      [] -> nil
    end
  end

  defp priority_badge(:urgent), do: "bg-error/10 text-error"
  defp priority_badge(:high), do: "bg-secondary/10 text-secondary"
  defp priority_badge(_), do: "bg-on-surface-variant/10 text-on-surface-variant"
end
