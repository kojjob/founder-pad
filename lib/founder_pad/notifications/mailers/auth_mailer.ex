defmodule FounderPad.Notifications.AuthMailer do
  @moduledoc "Auth-related transactional emails."
  import Swoosh.Email

  alias FounderPad.Mailer

  @from {"FounderPad", "noreply@founderpad.io"}

  def welcome(user) do
    new()
    |> to({user.name || "User", user.email})
    |> from(@from)
    |> subject("Welcome to FounderPad!")
    |> html_body("""
    <h1>Welcome to FounderPad!</h1>
    <p>Hi #{user.name || "there"},</p>
    <p>Your account has been created. Get started by creating your first workspace.</p>
    """)
    |> text_body("Welcome to FounderPad! Your account has been created.")
    |> Mailer.deliver()
  end

  def magic_link(email, token) do
    url = "#{FounderPadWeb.Endpoint.url()}/auth/magic-link?token=#{token}"

    new()
    |> to(email)
    |> from(@from)
    |> subject("Your FounderPad sign-in link")
    |> html_body("""
    <h2>Sign in to FounderPad</h2>
    <p>Click the link below to sign in. This link expires in 10 minutes.</p>
    <a href="#{url}">Sign in to FounderPad</a>
    """)
    |> text_body("Sign in to FounderPad: #{url}")
    |> Mailer.deliver()
  end

  def password_reset(user, token) do
    url = "#{FounderPadWeb.Endpoint.url()}/auth/reset-password?token=#{token}"

    new()
    |> to({user.name || "User", user.email})
    |> from(@from)
    |> subject("Reset your FounderPad password")
    |> html_body("""
    <h2>Password Reset</h2>
    <p>Click the link below to reset your password. This link expires in 1 hour.</p>
    <a href="#{url}">Reset Password</a>
    """)
    |> text_body("Reset your password: #{url}")
    |> Mailer.deliver()
  end
end
