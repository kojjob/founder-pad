defmodule FounderPadWeb.Hooks.AssignDefaults do
  @moduledoc """
  LiveView on_mount hook that assigns default values needed by the app layout.
  Loads the current_user from the session token.
  """
  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, _params, session, socket) do
    socket = assign(socket, active_nav: :dashboard)

    case session["user_token"] do
      nil ->
        {:cont, assign(socket, current_user: nil)}

      token ->
        case AshAuthentication.subject_to_user(token, FounderPad.Accounts.User) do
          {:ok, user} -> {:cont, assign(socket, current_user: user)}
          _ -> {:cont, assign(socket, current_user: nil)}
        end
    end
  end
end
