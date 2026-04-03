defmodule FounderPad.Notifications.OnboardingMailer do
  import Swoosh.Email
  alias FounderPad.Mailer
  alias FounderPad.Notifications.EmailLayout

  @from {"FounderPad", "noreply@founderpad.io"}

  def welcome(user) do
    unsub_url = EmailLayout.unsubscribe_url(user.id, "product_updates")

    body = EmailLayout.wrap("Welcome to FounderPad!", """
    <h2>Welcome aboard!</h2>
    <p>Hi #{user.name || "there"},</p>
    <p>Thanks for joining FounderPad. You're all set to start building.</p>
    <h3>What's next?</h3>
    <ul>
      <li><strong>Create your first AI agent</strong> — Head to the dashboard and set up an agent</li>
      <li><strong>Invite your team</strong> — Collaborate with teammates in your workspace</li>
      <li><strong>Explore the docs</strong> — Check out our guides for best practices</li>
    </ul>
    <p><a href="#{FounderPadWeb.Endpoint.url()}/dashboard" class="btn">Go to Dashboard</a></p>
    """, unsubscribe_url: unsub_url)

    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(@from)
    |> subject("Welcome to FounderPad!")
    |> html_body(body)
    |> Mailer.deliver()
  end

  def day_one_tips(user) do
    unsub_url = EmailLayout.unsubscribe_url(user.id, "product_updates")

    body = EmailLayout.wrap("Getting started with FounderPad", """
    <h2>Quick Start Tips</h2>
    <p>Hi #{user.name || "there"},</p>
    <p>Here are some tips to get the most out of FounderPad:</p>
    <ol>
      <li><strong>Set up your agent's system prompt</strong> — A good system prompt is key to great results</li>
      <li><strong>Connect your API keys</strong> — Add your Anthropic or OpenAI key in settings</li>
      <li><strong>Try the API</strong> — Generate an API key and start building integrations</li>
    </ol>
    <p><a href="#{FounderPadWeb.Endpoint.url()}/docs" class="btn">Read the Docs</a></p>
    """, unsubscribe_url: unsub_url)

    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(@from)
    |> subject("Quick start tips for FounderPad")
    |> html_body(body)
    |> Mailer.deliver()
  end

  def day_three_check_in(user) do
    unsub_url = EmailLayout.unsubscribe_url(user.id, "product_updates")

    body = EmailLayout.wrap("How's it going?", """
    <h2>How's it going?</h2>
    <p>Hi #{user.name || "there"},</p>
    <p>You've been with us for a few days now. How's everything going?</p>
    <p>If you have questions or need help, our help center has answers to common questions, or you can reach out to our support team.</p>
    <p><a href="#{FounderPadWeb.Endpoint.url()}/help" class="btn">Visit Help Center</a></p>
    """, unsubscribe_url: unsub_url)

    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(@from)
    |> subject("How's FounderPad working for you?")
    |> html_body(body)
    |> Mailer.deliver()
  end
end
