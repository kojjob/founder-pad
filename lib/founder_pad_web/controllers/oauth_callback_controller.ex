defmodule FounderPadWeb.OAuthCallbackController do
  use FounderPadWeb, :controller

  @doc """
  OAuth callback handler. In production, this would:
  1. Exchange auth code for access token
  2. Fetch user profile from provider
  3. Find or create user + social identity
  4. Create session and redirect to dashboard

  Requires env vars: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, etc.
  """
  def callback(conn, %{"provider" => provider} = _params) do
    conn
    |> put_flash(:error, "OAuth for #{provider} requires configuration. Set #{String.upcase(provider)}_CLIENT_ID and #{String.upcase(provider)}_CLIENT_SECRET env vars.")
    |> redirect(to: "/auth/login")
  end
end
