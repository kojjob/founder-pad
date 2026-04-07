defmodule LinkHub.Analytics do
  @moduledoc "Ash domain for application events and search console analytics."
  use Ash.Domain

  resources do
    resource LinkHub.Analytics.AppEvent do
      define(:create_event, action: :create)
      define(:list_events, action: :read)
      define(:list_by_org, action: :by_workspace, args: [:workspace_id])
    end

    resource LinkHub.Analytics.SearchConsoleData do
      define(:create_search_data, action: :create)
      define(:list_search_data, action: :read)
      define(:list_search_by_org, action: :by_workspace, args: [:workspace_id])
    end
  end

  @doc "Track an in-app event and broadcast via PubSub."
  def track(event_name, opts \\ []) do
    actor_id = Keyword.get(opts, :actor_id)
    org_id = Keyword.get(opts, :org_id)
    metadata = Keyword.get(opts, :metadata, %{})

    result =
      LinkHub.Analytics.AppEvent
      |> Ash.Changeset.for_create(:create, %{
        event_name: event_name,
        actor_id: actor_id,
        workspace_id: org_id,
        metadata: metadata,
        occurred_at: DateTime.utc_now()
      })
      |> Ash.create()

    case result do
      {:ok, event} ->
        broadcast_event(event)
        {:ok, event}

      error ->
        error
    end
  end

  defp broadcast_event(event) do
    if event.workspace_id do
      Phoenix.PubSub.broadcast(
        LinkHub.PubSub,
        "org_events:#{event.workspace_id}",
        {:app_event, event}
      )
    end
  end
end
