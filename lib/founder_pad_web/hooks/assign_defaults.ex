defmodule FounderPadWeb.Hooks.AssignDefaults do
  @moduledoc """
  LiveView on_mount hook that assigns default values needed by the app layout.
  Loads the current_user from the session token.
  Supports admin impersonation via session["impersonated_user_id"].
  """
  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, _params, session, socket) do
    socket = assign(socket, active_nav: :dashboard)

    case session["user_token"] do
      nil ->
        {:cont, assign(socket, current_user: nil, impersonating: false, admin_user: nil)}

      token ->
        case AshAuthentication.subject_to_user(token, FounderPad.Accounts.User) do
          {:ok, user} ->
            impersonated_id = session["impersonated_user_id"]

            if impersonated_id && user.is_admin do
              case Ash.get(FounderPad.Accounts.User, impersonated_id) do
                {:ok, imp_user} ->
                  {:cont,
                   assign(socket,
                     current_user: imp_user,
                     admin_user: user,
                     impersonating: true
                   )}

                _ ->
                  {:cont,
                   assign(socket,
                     current_user: user,
                     impersonating: false,
                     admin_user: nil
                   )}
              end
            else
              {:cont,
               assign(socket,
                 current_user: user,
                 impersonating: false,
                 admin_user: nil
               )}
            end

          _ ->
            {:cont, assign(socket, current_user: nil, impersonating: false, admin_user: nil)}
        end
    end
  end
end
