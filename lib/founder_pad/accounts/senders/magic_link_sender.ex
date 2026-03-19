defmodule FounderPad.Accounts.Senders.MagicLinkSender do
  @moduledoc "Sends magic link emails. Full implementation in Phase 5."
  use AshAuthentication.Sender

  @impl true
  def send(user_or_email, token, _opts) do
    # TODO: Replace with Swoosh mailer in Phase 5
    IO.puts("Magic link token for #{inspect(user_or_email)}: #{token}")
    :ok
  end
end
