defmodule LinkHub.Accounts.Changes.SendWelcomeEmail do
  @moduledoc """
  Ash after-action change that sends a welcome email to newly registered users.
  Attached to the `register_with_password` action on the User resource.
  """
  use Ash.Resource.Change

  alias LinkHub.Notifications.AuthMailer

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, user ->
      AuthMailer.welcome(user)
      {:ok, user}
    end)
  end
end
