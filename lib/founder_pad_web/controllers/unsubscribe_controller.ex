defmodule FounderPadWeb.UnsubscribeController do
  use FounderPadWeb, :controller

  def unsubscribe(conn, %{"token" => token}) do
    case Phoenix.Token.verify(FounderPadWeb.Endpoint, "unsubscribe", token, max_age: 30 * 86_400) do
      {:ok, {user_id, category}} ->
        user = Ash.get!(FounderPad.Accounts.User, user_id)
        prefs = user.email_preferences || %{}
        updated_prefs = Map.put(prefs, category, false)

        user
        |> Ash.Changeset.for_update(:update_email_preferences, %{email_preferences: updated_prefs})
        |> Ash.update!()

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, unsubscribe_success_html(category))

      {:error, _} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(400, unsubscribe_error_html())
    end
  end

  defp unsubscribe_success_html(category) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Unsubscribed — FounderPad</title>
    <style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#f4f4f5;font-family:system-ui,sans-serif;}.c{text-align:center;max-width:400px;padding:2rem;}h1{color:#1a1a2e;font-size:1.5rem;}p{color:#6b7280;}</style>
    </head>
    <body><div class="c"><h1>Unsubscribed</h1><p>You've been unsubscribed from #{String.replace(category, "_", " ")} emails.</p><p><a href="/settings">Manage all preferences</a></p></div></body>
    </html>
    """
  end

  defp unsubscribe_error_html do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Error — FounderPad</title>
    <style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#f4f4f5;font-family:system-ui,sans-serif;}.c{text-align:center;max-width:400px;padding:2rem;}h1{color:#1a1a2e;font-size:1.5rem;}p{color:#6b7280;}</style>
    </head>
    <body><div class="c"><h1>Link Expired</h1><p>This unsubscribe link has expired. <a href="/settings">Manage preferences</a></p></div></body>
    </html>
    """
  end
end
