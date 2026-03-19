defmodule FounderPadWeb.SettingsLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_nav: :settings,
       page_title: "Settings",
       two_factor_enabled: true,
       compact_ui: false,
       high_contrast: false,
       selected_theme: :midnight
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Header --%>
      <div class="flex items-baseline gap-3">
        <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
          Settings
        </h1>
        <span class="font-mono text-xs text-primary/40">v4.2.1</span>
      </div>

      <%!-- Two-column grid --%>
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <%!-- Left Column --%>
        <div class="lg:col-span-8 space-y-6">
          <%!-- General Profile Card --%>
          <div class="relative bg-surface-container rounded-xl p-6 overflow-hidden">
            <%!-- Decorative blur circle --%>
            <div class="absolute -top-10 -right-10 w-40 h-40 bg-primary/10 rounded-full blur-3xl pointer-events-none">
            </div>

            <h2 class="text-lg font-bold text-on-surface mb-6">General Profile</h2>

            <%!-- Avatar section --%>
            <div class="flex items-center gap-5 mb-6">
              <div class="relative">
                <div class="w-24 h-24 rounded-full ring-4 ring-primary/20 bg-surface-container-highest flex items-center justify-center overflow-hidden">
                  <span class="material-symbols-outlined text-4xl text-on-surface-variant">
                    person
                  </span>
                </div>
                <button class="absolute bottom-0 right-0 w-8 h-8 rounded-full bg-primary text-on-primary flex items-center justify-center shadow-lg hover:opacity-90 transition-opacity">
                  <span class="material-symbols-outlined text-sm">photo_camera</span>
                </button>
              </div>
              <div>
                <p class="text-sm font-medium text-on-surface">Profile Photo</p>
                <p class="text-xs text-on-surface-variant">JPG, PNG or GIF. Max 2MB.</p>
              </div>
            </div>

            <%!-- Form fields --%>
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                  Full Name
                </label>
                <input
                  type="text"
                  value="Sarah Chen"
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                  Email
                </label>
                <input
                  type="email"
                  value="sarah@founderpad.io"
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                  Department
                </label>
                <input
                  type="text"
                  value="Engineering"
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary"
                />
              </div>
            </div>
          </div>

          <%!-- Security Card --%>
          <div class="bg-surface-container rounded-xl p-6">
            <h2 class="text-lg font-bold text-on-surface mb-6">Security</h2>

            <%!-- 2FA Toggle --%>
            <div class="flex items-center justify-between mb-6">
              <div>
                <p class="text-sm font-medium text-on-surface">Two-Factor Authentication</p>
                <p class="text-xs text-on-surface-variant">
                  Add an extra layer of security to your account
                </p>
              </div>
              <button
                phx-click="toggle_2fa"
                class={[
                  "w-12 h-6 rounded-full transition-colors relative",
                  if(@two_factor_enabled, do: "bg-primary", else: "bg-surface-container-highest")
                ]}
              >
                <span class={[
                  "absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform",
                  if(@two_factor_enabled, do: "left-[26px]", else: "left-0.5")
                ]}>
                </span>
              </button>
            </div>

            <%!-- Action Buttons --%>
            <div class="space-y-3 mb-6">
              <button class="w-full flex items-center justify-between bg-surface-container-low rounded-lg px-4 py-3 hover:bg-surface-container-highest transition-colors group">
                <div class="flex items-center gap-3">
                  <span class="material-symbols-outlined text-on-surface-variant text-xl">
                    lock
                  </span>
                  <span class="text-sm font-medium text-on-surface">Change Password</span>
                </div>
                <span class="material-symbols-outlined text-on-surface-variant text-lg group-hover:translate-x-0.5 transition-transform">
                  chevron_right
                </span>
              </button>
              <button class="w-full flex items-center justify-between bg-surface-container-low rounded-lg px-4 py-3 hover:bg-surface-container-highest transition-colors group">
                <div class="flex items-center gap-3">
                  <span class="material-symbols-outlined text-on-surface-variant text-xl">
                    devices
                  </span>
                  <span class="text-sm font-medium text-on-surface">Active Sessions</span>
                </div>
                <span class="material-symbols-outlined text-on-surface-variant text-lg group-hover:translate-x-0.5 transition-transform">
                  chevron_right
                </span>
              </button>
            </div>

            <%!-- Login History --%>
            <div>
              <h3 class="text-sm font-medium text-on-surface-variant mb-3">Login History</h3>
              <div class="space-y-2">
                <div class="flex items-center justify-between text-xs">
                  <div class="flex items-center gap-2">
                    <span class="w-2 h-2 rounded-full bg-tertiary"></span>
                    <span class="text-on-surface">Chrome on macOS</span>
                  </div>
                  <span class="text-on-surface-variant font-mono">2 min ago</span>
                </div>
                <div class="flex items-center justify-between text-xs">
                  <div class="flex items-center gap-2">
                    <span class="w-2 h-2 rounded-full bg-on-surface-variant/30"></span>
                    <span class="text-on-surface">Safari on iPhone</span>
                  </div>
                  <span class="text-on-surface-variant font-mono">3 hours ago</span>
                </div>
                <div class="flex items-center justify-between text-xs">
                  <div class="flex items-center gap-2">
                    <span class="w-2 h-2 rounded-full bg-on-surface-variant/30"></span>
                    <span class="text-on-surface">Firefox on Windows</span>
                  </div>
                  <span class="text-on-surface-variant font-mono">Yesterday</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Right Column --%>
        <div class="lg:col-span-4 space-y-6">
          <%!-- Theme Preference Card --%>
          <div class="bg-surface-container-low rounded-xl p-6">
            <h2 class="text-lg font-bold text-on-surface mb-4">Theme Preference</h2>

            <%!-- Theme preview buttons --%>
            <div class="grid grid-cols-2 gap-3 mb-6">
              <button
                phx-click="select_theme"
                phx-value-theme="midnight"
                class={[
                  "rounded-lg p-3 transition-all",
                  if(@selected_theme == :midnight,
                    do: "border-2 border-primary bg-surface-container",
                    else: "border-2 border-transparent bg-surface-container hover:border-outline-variant/20"
                  )
                ]}
              >
                <div class="w-full h-16 rounded-md bg-[#0f0f1a] mb-2 flex items-center justify-center">
                  <div class="flex gap-1">
                    <div class="w-3 h-3 rounded-full bg-primary/60"></div>
                    <div class="w-3 h-3 rounded-full bg-secondary/60"></div>
                    <div class="w-3 h-3 rounded-full bg-tertiary/60"></div>
                  </div>
                </div>
                <p class="text-xs font-medium text-on-surface text-center">Midnight</p>
              </button>
              <button
                phx-click="select_theme"
                phx-value-theme="light"
                class={[
                  "rounded-lg p-3 transition-all",
                  if(@selected_theme == :light,
                    do: "border-2 border-primary bg-surface-container",
                    else: "border-2 border-transparent bg-surface-container hover:border-outline-variant/20"
                  )
                ]}
              >
                <div class="w-full h-16 rounded-md bg-gray-100 mb-2 flex items-center justify-center">
                  <div class="flex gap-1">
                    <div class="w-3 h-3 rounded-full bg-blue-400/60"></div>
                    <div class="w-3 h-3 rounded-full bg-purple-400/60"></div>
                    <div class="w-3 h-3 rounded-full bg-pink-400/60"></div>
                  </div>
                </div>
                <p class="text-xs font-medium text-on-surface text-center">Light Poly</p>
              </button>
            </div>

            <%!-- Toggles --%>
            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <span class="text-sm text-on-surface">Compact UI</span>
                <button
                  phx-click="toggle_compact_ui"
                  class={[
                    "w-12 h-6 rounded-full transition-colors relative",
                    if(@compact_ui, do: "bg-primary", else: "bg-surface-container-highest")
                  ]}
                >
                  <span class={[
                    "absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform",
                    if(@compact_ui, do: "left-[26px]", else: "left-0.5")
                  ]}>
                  </span>
                </button>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm text-on-surface">High Contrast</span>
                <button
                  phx-click="toggle_high_contrast"
                  class={[
                    "w-12 h-6 rounded-full transition-colors relative",
                    if(@high_contrast, do: "bg-primary", else: "bg-surface-container-highest")
                  ]}
                >
                  <span class={[
                    "absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform",
                    if(@high_contrast, do: "left-[26px]", else: "left-0.5")
                  ]}>
                  </span>
                </button>
              </div>
            </div>
          </div>

          <%!-- Usage Metrics Card --%>
          <div class="rounded-xl p-6 bg-gradient-to-br from-surface-container to-surface-container-low">
            <h2 class="text-lg font-bold text-on-surface mb-4">Usage Metrics</h2>

            <div class="space-y-4">
              <%!-- Compute Allocation --%>
              <div>
                <div class="flex items-center justify-between mb-1.5">
                  <span class="text-xs text-on-surface-variant">Compute Allocation</span>
                  <span class="text-xs font-mono text-secondary font-medium">82%</span>
                </div>
                <div class="w-full h-2 bg-surface-container-highest rounded-full overflow-hidden">
                  <div class="h-full bg-secondary rounded-full" style="width: 82%"></div>
                </div>
              </div>

              <%!-- Storage --%>
              <div>
                <div class="flex items-center justify-between mb-1.5">
                  <span class="text-xs text-on-surface-variant">Storage</span>
                  <span class="text-xs font-mono text-primary font-medium">45%</span>
                </div>
                <div class="w-full h-2 bg-surface-container-highest rounded-full overflow-hidden">
                  <div class="h-full bg-primary rounded-full" style="width: 45%"></div>
                </div>
              </div>
            </div>

            <button class="w-full mt-5 text-sm font-semibold text-primary border border-primary/30 rounded-lg py-2 hover:bg-primary/10 transition-colors">
              Upgrade Tier
            </button>
          </div>

          <%!-- Danger Zone Card --%>
          <div class="bg-error/5 border border-error/20 rounded-xl p-6">
            <h2 class="text-lg font-bold text-error mb-2">Danger Zone</h2>
            <p class="text-xs text-on-surface-variant mb-4">
              Permanently delete your account and all associated data. This action cannot be undone.
            </p>
            <button class="bg-error text-on-error px-4 py-2 rounded-lg text-sm font-semibold hover:opacity-90 transition-opacity">
              Delete Account
            </button>
          </div>
        </div>
      </div>

      <%!-- Footer Action Bar --%>
      <div class="flex items-center justify-end gap-3 pt-2">
        <button class="text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors px-4 py-2.5">
          Discard Changes
        </button>
        <button class="primary-gradient font-semibold px-6 py-2.5 rounded-lg text-sm">
          Save Preferences
        </button>
      </div>
    </div>
    """
  end

  def handle_event("toggle_2fa", _params, socket) do
    {:noreply, assign(socket, two_factor_enabled: !socket.assigns.two_factor_enabled)}
  end

  def handle_event("toggle_compact_ui", _params, socket) do
    {:noreply, assign(socket, compact_ui: !socket.assigns.compact_ui)}
  end

  def handle_event("toggle_high_contrast", _params, socket) do
    {:noreply, assign(socket, high_contrast: !socket.assigns.high_contrast)}
  end

  def handle_event("select_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, selected_theme: String.to_existing_atom(theme))}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: String.to_existing_atom(tab))}
  end
end
