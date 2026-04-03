defmodule FounderPad.Notifications.EmailLayout do
  @moduledoc "Shared branded HTML wrapper for all transactional emails."

  @doc "Wraps email content in the standard FounderPad branded template."
  def wrap(subject, inner_html, opts \\ []) do
    unsubscribe_url = Keyword.get(opts, :unsubscribe_url)
    preheader = Keyword.get(opts, :preheader, "")

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{subject}</title>
      <style>
        body { margin: 0; padding: 0; background-color: #f4f4f5; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
        .wrapper { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #4648d4; padding: 24px 32px; border-radius: 12px 12px 0 0; }
        .header h1 { color: white; font-size: 18px; margin: 0; font-weight: 600; }
        .content { background: white; padding: 32px; border-radius: 0 0 12px 12px; }
        .content h2 { color: #1a1a2e; font-size: 20px; margin-top: 0; }
        .content p { color: #4a4a6a; line-height: 1.6; font-size: 15px; }
        .btn { display: inline-block; padding: 12px 24px; background: #4648d4; color: white; text-decoration: none; border-radius: 8px; font-weight: 500; font-size: 14px; }
        .footer { text-align: center; padding: 24px; font-size: 12px; color: #9ca3af; }
        .footer a { color: #6b7280; }
        .preheader { display: none; max-height: 0; overflow: hidden; }
      </style>
    </head>
    <body>
      <div class="preheader">#{preheader}</div>
      <div class="wrapper">
        <div class="header">
          <h1>FounderPad</h1>
        </div>
        <div class="content">
          #{inner_html}
        </div>
        <div class="footer">
          <p>&copy; #{DateTime.utc_now().year} FounderPad. All rights reserved.</p>
          #{if unsubscribe_url, do: "<p><a href=\"#{unsubscribe_url}\">Unsubscribe</a> from these emails.</p>", else: ""}
        </div>
      </div>
    </body>
    </html>
    """
  end
end
