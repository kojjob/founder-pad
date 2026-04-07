defmodule LinkHub.Notifications.InviteMailer do
  @moduledoc "Sends team invitation emails."
  import Swoosh.Email

  alias LinkHub.Mailer

  @from {"LinkHub", "noreply@founderpad.io"}

  def invite(email, org_name) do
    register_url = "#{LinkHubWeb.Endpoint.url()}/auth/register"

    new()
    |> to(email)
    |> from(@from)
    |> subject("You've been invited to join #{org_name} on LinkHub")
    |> html_body("""
    <h2>You're invited!</h2>
    <p>You've been invited to join <strong>#{org_name}</strong> on LinkHub.</p>
    <p>Create your account to get started:</p>
    <a href="#{register_url}">Join #{org_name}</a>
    """)
    |> text_body(
      "You've been invited to join #{org_name} on LinkHub. Sign up at: #{register_url}"
    )
    |> Mailer.deliver()
  end
end
