defmodule FounderPad.Notifications.InviteMailer do
  @moduledoc "Sends team invitation emails."
  import Swoosh.Email

  alias FounderPad.Mailer

  @from {"FounderPad", "noreply@founderpad.io"}

  def invite(email, org_name) do
    register_url = "#{FounderPadWeb.Endpoint.url()}/auth/register"

    new()
    |> to(email)
    |> from(@from)
    |> subject("You've been invited to join #{org_name} on FounderPad")
    |> html_body("""
    <h2>You're invited!</h2>
    <p>You've been invited to join <strong>#{org_name}</strong> on FounderPad.</p>
    <p>Create your account to get started:</p>
    <a href="#{register_url}">Join #{org_name}</a>
    """)
    |> text_body("You've been invited to join #{org_name} on FounderPad. Sign up at: #{register_url}")
    |> Mailer.deliver()
  end
end
