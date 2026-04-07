defmodule LinkHub.Notifications.AgentMailer do
  @moduledoc "AI agent-related transactional emails."
  import Swoosh.Email

  alias LinkHub.Mailer

  @from {"LinkHub", "noreply@founderpad.io"}

  def agent_run_completed(user, agent, conversation) do
    url = "#{LinkHubWeb.Endpoint.url()}/conversations/#{conversation.id}"

    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(@from)
    |> subject("Agent \"#{agent.name}\" completed a run")
    |> html_body("""
    <h2>Agent Run Complete</h2>
    <p>Your agent <strong>#{agent.name}</strong> has finished processing.</p>
    <a href="#{url}">View Conversation</a>
    """)
    |> text_body("Agent #{agent.name} completed. View at: #{url}")
    |> Mailer.deliver()
  end

  def agent_run_failed(user, agent, error) do
    new()
    |> to({user.name || "User", to_string(user.email)})
    |> from(@from)
    |> subject("Agent \"#{agent.name}\" run failed")
    |> html_body("""
    <h2>Agent Run Failed</h2>
    <p>Your agent <strong>#{agent.name}</strong> encountered an error:</p>
    <pre>#{error}</pre>
    """)
    |> text_body("Agent #{agent.name} failed: #{error}")
    |> Mailer.deliver()
  end
end
