defmodule FounderPadWeb.TwoFactorLive do
  use FounderPadWeb, :live_view

  alias FounderPad.Accounts.UserTotp

  require Ash.Query

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    totp = load_totp(user)

    {:ok,
     assign(socket,
       page_title: "Two-Factor Authentication",
       active_nav: :settings,
       totp: totp,
       setup_mode: false,
       setup_secret: nil,
       setup_uri: nil,
       backup_codes: nil,
       verify_error: nil,
       flash_message: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto space-y-8">
      <div class="flex items-baseline gap-3">
        <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
          Two-Factor Authentication
        </h1>
      </div>

      <div class="bg-surface-container rounded-xl p-6 space-y-6">
        <%= if @backup_codes do %>
          <%!-- Show backup codes after successful enable --%>
          <div class="space-y-4">
            <div class="flex items-center gap-2 text-green-400">
              <span class="material-symbols-outlined">check_circle</span>
              <p class="font-semibold">Two-factor authentication enabled</p>
            </div>

            <div class="bg-surface-container-highest rounded-lg p-4 space-y-3">
              <h3 class="text-lg font-bold text-on-surface">Backup Codes</h3>
              <p class="text-sm text-on-surface-variant">
                Save these codes in a safe place. Each code can only be used once.
              </p>
              <div class="grid grid-cols-2 gap-2">
                <code
                  :for={code <- @backup_codes}
                  class="font-mono text-sm bg-surface-container px-3 py-1.5 rounded text-on-surface"
                >
                  {code}
                </code>
              </div>
            </div>

            <button
              phx-click="dismiss_backup_codes"
              class="px-4 py-2 bg-primary text-on-primary rounded-lg font-medium hover:bg-primary/90 transition-colors"
            >
              I've saved my codes
            </button>
          </div>
        <% else %>
          <%!-- Status display --%>
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-bold text-on-surface">Status</h2>
              <%= if @totp && @totp.enabled do %>
                <span class="inline-flex items-center gap-1.5 text-green-400 font-medium mt-1">
                  <span class="w-2 h-2 bg-green-400 rounded-full"></span> Enabled
                </span>
              <% else %>
                <span class="inline-flex items-center gap-1.5 text-on-surface-variant font-medium mt-1">
                  <span class="w-2 h-2 bg-on-surface-variant rounded-full"></span> Disabled
                </span>
              <% end %>
            </div>

            <%= if @totp && @totp.enabled do %>
              <button
                phx-click="disable_2fa"
                class="px-4 py-2 bg-error/10 text-error rounded-lg font-medium hover:bg-error/20 transition-colors"
              >
                Disable 2FA
              </button>
            <% else %>
              <%= unless @setup_mode do %>
                <button
                  phx-click="start_setup"
                  class="px-4 py-2 bg-primary text-on-primary rounded-lg font-medium hover:bg-primary/90 transition-colors"
                >
                  Enable 2FA
                </button>
              <% end %>
            <% end %>
          </div>

          <%!-- Setup mode --%>
          <%= if @setup_mode do %>
            <div class="border-t border-outline-variant/20 pt-6 space-y-6">
              <div class="space-y-3">
                <h3 class="text-lg font-bold text-on-surface">Setup Instructions</h3>
                <ol class="list-decimal list-inside space-y-2 text-sm text-on-surface-variant">
                  <li>Open your authenticator app (Google Authenticator, Authy, etc.)</li>
                  <li>Scan the QR code or manually enter the secret key below</li>
                  <li>Enter the 6-digit code from your authenticator app</li>
                </ol>
              </div>

              <div class="bg-surface-container-highest rounded-lg p-4 space-y-2">
                <p class="text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                  OTPAuth URI
                </p>
                <code class="block text-sm font-mono text-on-surface break-all">
                  {@setup_uri}
                </code>
              </div>

              <div class="bg-surface-container-highest rounded-lg p-4 space-y-2">
                <p class="text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                  Secret Key (manual entry)
                </p>
                <code class="block text-lg font-mono text-primary tracking-widest">
                  {@setup_secret}
                </code>
              </div>

              <.form
                for={%{}}
                phx-submit="verify_code"
                id="verify-totp-form"
                class="space-y-4"
              >
                <div>
                  <label class="block text-sm font-medium text-on-surface mb-1">
                    Verify Code
                  </label>
                  <input
                    type="text"
                    name="code"
                    placeholder="000000"
                    maxlength="6"
                    inputmode="numeric"
                    pattern="[0-9]*"
                    autocomplete="one-time-code"
                    class="w-full max-w-[200px] px-4 py-2 bg-surface-container-highest text-on-surface rounded-lg border border-outline-variant/30 focus:border-primary focus:ring-1 focus:ring-primary text-center text-2xl font-mono tracking-[0.5em]"
                  />
                  <%= if @verify_error do %>
                    <p class="text-error text-sm mt-1">{@verify_error}</p>
                  <% end %>
                </div>

                <button
                  type="submit"
                  class="px-4 py-2 bg-primary text-on-primary rounded-lg font-medium hover:bg-primary/90 transition-colors"
                >
                  Verify & Enable
                </button>
              </.form>
            </div>
          <% end %>

          <%= if @flash_message do %>
            <p class="text-green-400 font-medium">{@flash_message}</p>
          <% end %>
        <% end %>
      </div>

      <div class="text-center">
        <a href="/settings" class="text-sm text-primary hover:text-primary/80 transition-colors">
          Back to Settings
        </a>
      </div>
    </div>
    """
  end

  def handle_event("start_setup", _params, socket) do
    user = socket.assigns.current_user

    # Create TOTP record (or use existing unenabled one)
    totp =
      case load_totp(user) do
        %{enabled: false} = existing ->
          existing

        nil ->
          UserTotp
          |> Ash.Changeset.for_create(:create, %{user_id: user.id})
          |> Ash.create!()
      end

    email = to_string(user.email)
    uri = "otpauth://totp/FounderPad:#{email}?secret=#{totp.secret}&issuer=FounderPad"

    {:noreply,
     assign(socket,
       setup_mode: true,
       setup_secret: totp.secret,
       setup_uri: uri,
       totp: totp,
       verify_error: nil
     )}
  end

  def handle_event("verify_code", %{"code" => code}, socket) do
    totp = socket.assigns.totp

    if UserTotp.verify_code(totp.secret, code) do
      {:ok, enabled_totp} =
        totp
        |> Ash.Changeset.for_update(:enable, %{})
        |> Ash.update()

      {:noreply,
       assign(socket,
         totp: enabled_totp,
         setup_mode: false,
         setup_secret: nil,
         setup_uri: nil,
         verify_error: nil,
         backup_codes: totp.backup_codes
       )}
    else
      {:noreply, assign(socket, verify_error: "Invalid code. Please try again.")}
    end
  end

  def handle_event("dismiss_backup_codes", _params, socket) do
    {:noreply, assign(socket, backup_codes: nil)}
  end

  def handle_event("disable_2fa", _params, socket) do
    totp = socket.assigns.totp

    {:ok, disabled_totp} =
      totp
      |> Ash.Changeset.for_update(:disable, %{})
      |> Ash.update()

    {:noreply,
     assign(socket,
       totp: disabled_totp,
       flash_message: "Two-factor authentication disabled"
     )}
  end

  defp load_totp(user) do
    case UserTotp
         |> Ash.Query.for_read(:by_user, %{user_id: user.id})
         |> Ash.read() do
      {:ok, [totp]} -> totp
      _ -> nil
    end
  end
end
