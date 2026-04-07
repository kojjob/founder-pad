defmodule LinkHub.Messaging.Notifiers.MessageNotifier do
  @moduledoc """
  Broadcasts message events to Phoenix PubSub after successful Ash actions.
  Subscribers (LiveView, Phoenix Channels) receive these events for real-time UI updates.
  """
  use Ash.Notifier

  @impl true
  def notify(
        %Ash.Notifier.Notification{resource: LinkHub.Messaging.Message, action: %{name: :send}} =
          notification
      ) do
    message = notification.data

    Phoenix.PubSub.broadcast(
      LinkHub.PubSub,
      "channel:#{message.channel_id}",
      {:new_message, message}
    )

    :ok
  end

  def notify(
        %Ash.Notifier.Notification{resource: LinkHub.Messaging.Message, action: %{name: :edit}} =
          notification
      ) do
    message = notification.data

    Phoenix.PubSub.broadcast(
      LinkHub.PubSub,
      "channel:#{message.channel_id}",
      {:message_edited, message}
    )

    :ok
  end

  def notify(
        %Ash.Notifier.Notification{
          resource: LinkHub.Messaging.Message,
          action: %{name: :soft_delete}
        } = notification
      ) do
    message = notification.data

    Phoenix.PubSub.broadcast(
      LinkHub.PubSub,
      "channel:#{message.channel_id}",
      {:message_deleted, message}
    )

    :ok
  end

  def notify(_notification), do: :ok
end
