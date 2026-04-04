defmodule FounderPadWeb.Presence do
  @moduledoc "Phoenix Presence for real-time collaboration tracking."

  use Phoenix.Presence,
    otp_app: :founder_pad,
    pubsub_server: FounderPad.PubSub
end
