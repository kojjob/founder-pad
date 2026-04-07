defmodule FounderPadWeb.Hooks.RequireAdmin do
  @moduledoc "LiveView on_mount hook that redirects non-admin users."
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_navigate: 2]

  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && user.is_admin do
      {:cont, assign(socket, admin_user: user)}
    else
      {:halt, push_navigate(socket, to: "/dashboard")}
    end
  end
end
