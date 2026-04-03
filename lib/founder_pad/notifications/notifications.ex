defmodule FounderPad.Notifications do
  use Ash.Domain

  resources do
    resource FounderPad.Notifications.Notification do
      define :create_notification, action: :create
      define :list_notifications, action: :read
      define :mark_as_read, action: :mark_read
      define :mark_all_read, action: :mark_all_read
    end

    resource FounderPad.Notifications.EmailLog do
      define :create_email_log, action: :create
      define :list_email_logs, action: :read
    end

    resource FounderPad.Notifications.PushSubscription do
      define :create_push_subscription, action: :create
      define :deactivate_push_subscription, action: :deactivate
      define :list_active_push_subscriptions, action: :active_for_user, args: [:user_id]
    end
  end

  @doc "Broadcast a notification to a user via PubSub."
  def broadcast_to_user(user_id, notification) do
    Phoenix.PubSub.broadcast(
      FounderPad.PubSub,
      "user_notifications:#{user_id}",
      {:new_notification, notification}
    )
  end
end
