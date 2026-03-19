defmodule FounderPadWeb.Hooks.AssignDefaults do
  @moduledoc """
  LiveView on_mount hook that assigns default values needed by the app layout.
  """
  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, active_nav: :dashboard)}
  end
end
