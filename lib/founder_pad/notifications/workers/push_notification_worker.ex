defmodule FounderPad.Notifications.Workers.PushNotificationWorker do
  @moduledoc "Oban worker that sends push notifications to all of a user's registered devices."
  use Oban.Worker, queue: :default, max_attempts: 3

  alias FounderPad.Notifications.PushSender

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "title" => title, "body" => body} = args}) do
    action_url = args["action_url"] || "/"
    notification = %{title: title, body: body, action_url: action_url}

    subscriptions =
      FounderPad.Notifications.PushSubscription
      |> Ash.Query.for_read(:active_for_user, %{user_id: user_id})
      |> Ash.read!()

    Enum.each(subscriptions, fn sub ->
      case sub.type do
        :fcm ->
          PushSender.send_fcm(notification, sub.token)

        :web_push ->
          PushSender.send_web_push(notification, sub.token)
      end

      # Touch last_used_at
      sub |> Ash.Changeset.for_update(:touch, %{}) |> Ash.update()
    end)

    :ok
  end
end
