defmodule FounderPadWeb.Plugs.MaintenanceMode do
  @moduledoc "Serves 503 maintenance page when maintenance mode is enabled."
  import Plug.Conn

  @maintenance_html """
  <!DOCTYPE html>
  <html lang="en" class="dark">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>503 — Maintenance | FounderPad</title>
    <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@700;800&family=Inter:wght@400;500&family=JetBrains+Mono:wght@400&display=swap" rel="stylesheet" />
    <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=swap" rel="stylesheet" />
    <style>
      body { background: #0b1326; color: #dae2fd; font-family: 'Inter', system-ui; margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
      .headline { font-family: 'Manrope', system-ui; }
      .mono { font-family: 'JetBrains Mono', monospace; }
      .primary { color: #c0c1ff; }
      .muted { color: #c7c4d7; }
      .error-code { font-family: 'JetBrains Mono'; font-size: 120px; font-weight: 700; color: #c0c1ff; opacity: 0.1; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); }
    </style>
  </head>
  <body>
    <div style="position: relative; text-align: center; max-width: 500px; padding: 2rem;">
      <div class="error-code">503</div>
      <div style="position: relative; z-index: 1;">
        <span class="material-symbols-outlined" style="font-size: 64px; color: #c0c1ff; opacity: 0.6;">construction</span>
        <h1 class="headline" style="font-size: 2.5rem; margin: 1rem 0 0.5rem;">We'll be right back.</h1>
        <p class="muted" style="font-size: 1rem; line-height: 1.6; margin-bottom: 2rem;">We're performing scheduled maintenance. Please check back in a few minutes.</p>
        <p class="mono" style="font-size: 11px; color: #464554; margin-top: 2rem;">ERROR_CODE: 503_SERVICE_UNAVAILABLE // FOUNDERPAD</p>
      </div>
    </div>
  </body>
  </html>
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    if maintenance_enabled?() and not bypass?(conn) do
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(503, @maintenance_html)
      |> halt()
    else
      conn
    end
  end

  defp maintenance_enabled? do
    System.get_env("MAINTENANCE_MODE") == "true" ||
      try do
        FounderPad.FeatureFlags.enabled?("maintenance_mode")
      rescue
        _ -> false
      end
  end

  defp bypass?(conn) do
    conn = Plug.Conn.fetch_cookies(conn)

    case conn.cookies["maintenance_bypass"] do
      secret when is_binary(secret) ->
        expected = Application.get_env(:founder_pad, :maintenance_bypass_secret, "dev-bypass")
        secret == expected

      _ ->
        false
    end
  end
end
