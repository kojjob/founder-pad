defmodule LinkHubWeb.UserSocket do
  @moduledoc "Phoenix Socket for authenticated WebSocket connections."
  use Phoenix.Socket

  channel "channel:*", LinkHubWeb.MessageChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(LinkHubWeb.Endpoint, "user socket", token, max_age: 86_400) do
      {:ok, user_id} ->
        user = Ash.get!(LinkHub.Accounts.User, user_id)
        {:ok, assign(socket, :current_user, user)}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "users_socket:#{socket.assigns.current_user.id}"
end
