defmodule LinkHub.Mailer do
  @moduledoc "Swoosh mailer for sending transactional emails."
  use Swoosh.Mailer, otp_app: :link_hub
end
