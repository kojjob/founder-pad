defmodule FounderPad.Accounts.Senders.PasswordResetSender do
  @moduledoc "Sends password reset emails. Full implementation in Phase 5."
  use AshAuthentication.Sender

  @impl true
  def send(user, token, _opts) do
    IO.puts("Password reset token for #{inspect(user)}: #{token}")
    :ok
  end
end
