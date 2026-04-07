defmodule LinkHubWeb.Presence do
  @moduledoc """
  Tracks user presence across channels using Phoenix.Presence (CRDT-based).
  Provides online/away/offline status per channel.
  """
  use Phoenix.Presence,
    otp_app: :link_hub,
    pubsub_server: LinkHub.PubSub
end
