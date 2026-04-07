defmodule LinkHubWeb.MessageChannel do
  @moduledoc """
  Phoenix Channel for real-time messaging within a workspace channel.
  Handles message sending, typing indicators, and presence tracking.
  """
  use Phoenix.Channel

  alias LinkHubWeb.Presence

  @impl true
  def join("channel:" <> channel_id, _params, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :channel_id, channel_id)}
  end

  @impl true
  def handle_info(:after_join, socket) do
    user = socket.assigns.current_user

    {:ok, _} =
      Presence.track(socket, user.id, %{
        name: user.name,
        email: user.email,
        online_at: System.system_time(:second)
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_in("new_message", %{"body" => body} = params, socket) do
    user = socket.assigns.current_user
    channel_id = socket.assigns.channel_id

    case LinkHub.Messaging.Message
         |> Ash.Changeset.for_create(:send, %{
           body: body,
           channel_id: channel_id,
           author_id: user.id,
           parent_message_id: params["parent_message_id"]
         })
         |> Ash.create() do
      {:ok, message} ->
        message = Ash.load!(message, [:author])

        broadcast!(socket, "new_message", %{
          id: message.id,
          body: message.body,
          author_id: message.author_id,
          author_name: message.author.name,
          parent_message_id: message.parent_message_id,
          inserted_at: message.inserted_at
        })

        {:reply, :ok, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: inspect(changeset.errors)}}, socket}
    end
  end

  def handle_in("typing", _params, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "typing", %{
      user_id: user.id,
      user_name: user.name
    })

    {:noreply, socket}
  end

  def handle_in("stop_typing", _params, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "stop_typing", %{
      user_id: user.id
    })

    {:noreply, socket}
  end
end
