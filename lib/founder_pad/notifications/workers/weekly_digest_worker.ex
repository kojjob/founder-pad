defmodule FounderPad.Notifications.Workers.WeeklyDigestWorker do
  @moduledoc "Sends weekly usage digest to users who have opted in."
  use Oban.Worker, queue: :mailers, max_attempts: 3

  @impl Oban.Worker
  def perform(_job) do
    FounderPad.Accounts.User
    |> Ash.read!()
    |> Enum.filter(fn user ->
      prefs = user.email_preferences || %{}
      prefs["weekly_digest"] != false
    end)
    |> Enum.each(fn user ->
      send_digest(user)
    end)

    :ok
  end

  defp send_digest(user) do
    import Swoosh.Email
    alias FounderPad.Notifications.EmailLayout

    unsub_url = EmailLayout.unsubscribe_url(user.id, "weekly_digest")

    body =
      EmailLayout.wrap(
        "Your Weekly Summary",
        """
        <h2>Your Weekly Summary</h2>
        <p>Hi #{user.name || "there"},</p>
        <p>Here's a quick look at your FounderPad activity this week.</p>
        <p>Visit your dashboard for detailed analytics.</p>
        <p><a href="#{FounderPadWeb.Endpoint.url()}/dashboard" class="btn">View Dashboard</a></p>
        """, unsubscribe_url: unsub_url)

    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from({"FounderPad", "noreply@founderpad.io"})
    |> subject("Your FounderPad Weekly Summary")
    |> html_body(body)
    |> FounderPad.Mailer.deliver()
  end
end
