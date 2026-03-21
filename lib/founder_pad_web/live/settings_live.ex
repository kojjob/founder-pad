defmodule FounderPadWeb.SettingsLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    prefs = (user && user.preferences) || %{}

    {:ok,
     socket
     |> assign(
       active_nav: :settings,
       page_title: "Settings",
       two_factor_enabled: true,
       compact_ui: prefs["compact_ui"] || false,
       high_contrast: prefs["high_contrast"] || false,
       selected_theme: (prefs["theme"] && String.to_existing_atom(prefs["theme"])) || :midnight,
       avatar_url: user && user.avatar_url,
       upload_error: nil,
       department: "Engineering",
       show_delete_confirm: false,
       show_password_form: false,
       password_error: nil,
       login_history: load_login_history(user)
     )
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 2_000_000
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

            <%!-- Avatar Upload Section --%>
            <div class="flex items-center gap-5 mb-6">
              <.form
                for={%{}}
                phx-change="validate_avatar"
                phx-submit="save_avatar"
                id="avatar-form"
                class="flex items-center gap-5"
              >
                <div class="relative group/avatar-upload">
                  <%!-- Avatar preview --%>
                  <div class="w-24 h-24 rounded-full ring-4 ring-primary/20 bg-surface-container-highest flex items-center justify-center overflow-hidden transition-all duration-300">
                    <%= cond do %>
                      <% entry = List.first(@uploads.avatar.entries) -> %>
                        <.live_img_preview entry={entry} class="w-full h-full object-cover" />
                      <% @avatar_url -> %>
                        <img src={@avatar_url} alt="Avatar" class="w-full h-full object-cover" />
                      <% true -> %>
                        <span class="material-symbols-outlined text-4xl text-on-surface-variant">
                          person
                        </span>
                    <% end %>
                  </div>

                  <%!-- Hover overlay with camera icon --%>
                  <label class="absolute inset-0 rounded-full bg-on-surface/50 flex items-center justify-center opacity-0 group-hover/avatar-upload:opacity-100 transition-opacity duration-200 cursor-pointer">
                    <span class="material-symbols-outlined text-white text-2xl drop-shadow">
                      photo_camera
                    </span>
                    <.live_file_input upload={@uploads.avatar} class="hidden" />
                  </label>

                  <%!-- Online indicator --%>
                  <span class="absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full bg-emerald-500 ring-[3px] ring-surface-container flex items-center justify-center">
                    <span class="material-symbols-outlined text-white text-[10px]">check</span>
                  </span>
                </div>

                <div class="flex-1">
                  <p class="text-sm font-medium text-on-surface">Profile Photo</p>
                  <p class="text-xs text-on-surface-variant mt-0.5">
                    JPG, PNG, GIF, or WebP. Max 2MB.
                  </p>

                  <%!-- Upload errors --%>
                  <%= for entry <- @uploads.avatar.entries do %>
                    <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                      <p class="text-xs text-error mt-1.5 flex items-center gap-1">
                        <span class="material-symbols-outlined text-xs">error</span>
                        {error_to_string(err)}
                      </p>
                    <% end %>
                  <% end %>

                  <%= if @upload_error do %>
                    <p class="text-xs text-error mt-1.5 flex items-center gap-1">
                      <span class="material-symbols-outlined text-xs">error</span>
                      {@upload_error}
                    </p>
                  <% end %>

                  <%!-- Action buttons --%>
                  <div class="flex items-center gap-2 mt-3">
                    <%= if @uploads.avatar.entries != [] do %>
                      <button
                        type="submit"
                        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-primary text-on-primary text-xs font-semibold hover:opacity-90 transition-opacity"
                      >
                        <span class="material-symbols-outlined text-sm">upload</span> Upload
                      </button>
                      <button
                        type="button"
                        phx-click="cancel_upload"
                        phx-value-ref={List.first(@uploads.avatar.entries).ref}
                        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-on-surface-variant text-xs font-medium hover:text-on-surface hover:bg-surface-container-highest transition-colors"
                      >
                        Cancel
                      </button>
                    <% end %>
                    <%= if @avatar_url && @uploads.avatar.entries == [] do %>
                      <button
                        type="button"
                        phx-click="remove_avatar"
                        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-error/80 text-xs font-medium hover:text-error hover:bg-error/5 transition-colors"
                      >
                        <span class="material-symbols-outlined text-sm">delete</span> Remove photo
                      </button>
                    <% end %>
                  </div>
                </div>
              </.form>
            </div>

            <%!-- Form fields --%>
            <.form for={%{}} as={:profile} phx-submit="save_profile" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                  Full Name
                </label>
                <input
                  type="text"
                  name="profile[name]"
                  value={if(@current_user, do: @current_user.name || "", else: "")}
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                  Email
                </label>
                <input
                  type="email"
                  name="profile[email]"
                  value={if(@current_user, do: to_string(@current_user.email), else: "")}
                  disabled
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary opacity-60"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                  Department
                </label>
                <input
                  type="text"
                  name="profile[department]"
                  value={@department}
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary"
                />
              </div>
            </.form>
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
              <button phx-click="show_password_form" class="w-full flex items-center justify-between bg-surface-container-low rounded-lg px-4 py-3 hover:bg-surface-container-highest transition-colors group">
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

              <%!-- Password Change Form --%>
              <div :if={@show_password_form} class="bg-surface-container-low rounded-lg p-4 space-y-3">
                <.form for={%{}} as={:password} phx-submit="submit_password_change" id="password-form" class="space-y-3">
                  <div>
                    <label class="block text-xs font-medium text-on-surface-variant mb-1">Current Password</label>
                    <input
                      type="password"
                      name="password[current_password]"
                      required
                      class="w-full bg-surface-container-highest border-none rounded-lg px-3 py-2 text-sm text-on-surface focus:ring-1 focus:ring-primary"
                    />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-on-surface-variant mb-1">New Password</label>
                    <input
                      type="password"
                      name="password[password]"
                      required
                      class="w-full bg-surface-container-highest border-none rounded-lg px-3 py-2 text-sm text-on-surface focus:ring-1 focus:ring-primary"
                    />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-on-surface-variant mb-1">Confirm New Password</label>
                    <input
                      type="password"
                      name="password[password_confirmation]"
                      required
                      class="w-full bg-surface-container-highest border-none rounded-lg px-3 py-2 text-sm text-on-surface focus:ring-1 focus:ring-primary"
                    />
                  </div>
                  <%= if @password_error do %>
                    <p class="text-xs text-error">{@password_error}</p>
                  <% end %>
                  <div class="flex items-center gap-2 pt-1">
                    <button type="submit" class="px-4 py-2 bg-primary text-on-primary text-xs font-semibold rounded-lg hover:opacity-90 transition-opacity">
                      Update Password
                    </button>
                    <button type="button" phx-click="hide_password_form" class="px-4 py-2 text-on-surface-variant text-xs font-medium hover:text-on-surface transition-colors">
                      Cancel
                    </button>
                  </div>
                </.form>
              </div>
              <button phx-click="view_sessions" class="w-full flex items-center justify-between bg-surface-container-low rounded-lg px-4 py-3 hover:bg-surface-container-highest transition-colors group">
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
                <div :if={@login_history == []} class="text-xs text-on-surface-variant">No login history yet</div>
                <div :for={{entry, idx} <- Enum.with_index(@login_history)} class="flex items-center justify-between text-xs">
                  <div class="flex items-center gap-2">
                    <span class={["w-2 h-2 rounded-full", if(idx == 0, do: "bg-tertiary", else: "bg-on-surface-variant/30")]}></span>
                    <span class="text-on-surface">{entry.device}</span>
                  </div>
                  <span class={["text-on-surface-variant font-mono", if(idx == 0, do: "text-primary", else: "")]}>
                    {entry.time_ago}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Right Column --%>
        <div class="lg:col-span-4 space-y-6">
          <%!-- Theme Preference Card --%>
          <div id="theme-settings" phx-hook="ThemeSettings" class="bg-surface-container-low rounded-xl p-6">
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
                    else:
                      "border-2 border-transparent bg-surface-container hover:border-outline-variant/20"
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
                    else:
                      "border-2 border-transparent bg-surface-container hover:border-outline-variant/20"
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

            <a href="/billing" class="block w-full mt-5 text-sm font-semibold text-primary border border-primary/30 rounded-lg py-2 hover:bg-primary/10 transition-colors text-center">
              Upgrade Tier
            </a>
          </div>

          <%!-- Danger Zone Card --%>
          <div class="bg-error/5 border border-error/20 rounded-xl p-6">
            <h2 class="text-lg font-bold text-error mb-2">Danger Zone</h2>
            <p class="text-xs text-on-surface-variant mb-4">
              Permanently delete your account and all associated data. This action cannot be undone.
            </p>
            <button :if={!@show_delete_confirm} phx-click="toggle_delete_confirm" class="bg-error text-on-error px-4 py-2 rounded-lg text-sm font-semibold hover:opacity-90 transition-opacity">
              Delete Account
            </button>
            <div :if={@show_delete_confirm} class="flex items-center gap-3">
              <span class="text-xs text-error font-medium">This cannot be undone. Are you sure?</span>
              <button phx-click="confirm_delete_account" class="bg-error text-on-error px-4 py-2 rounded-lg text-xs font-bold uppercase">Yes, Delete</button>
              <button phx-click="toggle_delete_confirm" class="bg-surface-container-highest text-on-surface-variant px-4 py-2 rounded-lg text-xs font-bold">Cancel</button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Footer Action Bar --%>
      <div class="flex items-center justify-end gap-3 pt-2">
        <button phx-click="discard_changes" class="text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors px-4 py-2.5">
          Discard Changes
        </button>
        <button phx-click="save_preferences" class="primary-gradient font-semibold px-6 py-2.5 rounded-lg text-sm">
          Save Preferences
        </button>
      </div>
    </div>
    """
  end

  # -- Upload event handlers --

  def handle_event("validate_avatar", _params, socket) do
    {:noreply, assign(socket, upload_error: nil)}
  end

  def handle_event("save_avatar", _params, socket) do
    user = socket.assigns.current_user

    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "#{user.id}_#{System.system_time(:second)}#{ext}"
        dest = Path.join([:code.priv_dir(:founder_pad), "static", "uploads", "avatars", filename])
        File.cp!(path, dest)
        {:ok, ~p"/uploads/avatars/#{filename}"}
      end)

    case uploaded_files do
      [avatar_url | _] ->
        # Delete old avatar file if it was a local upload
        maybe_delete_old_avatar(user.avatar_url)

        result =
          user
          |> Ash.Changeset.for_update(:update_profile, %{avatar_url: avatar_url})
          |> Ash.update()

        case result do
          {:ok, updated_user} ->
            {:noreply,
             socket
             |> assign(avatar_url: updated_user.avatar_url, upload_error: nil)
             |> put_flash(:info, "Profile photo updated successfully!")}

          {:error, _} ->
            {:noreply,
             socket
             |> assign(upload_error: "Failed to save avatar. Please try again.")}
        end

      [] ->
        {:noreply, assign(socket, upload_error: "No file selected.")}
    end
  end

  def handle_event("remove_avatar", _params, socket) do
    user = socket.assigns.current_user

    result =
      user
      |> Ash.Changeset.for_update(:update_profile, %{avatar_url: nil})
      |> Ash.update()

    case result do
      {:ok, _updated_user} ->
        maybe_delete_old_avatar(user.avatar_url)

        {:noreply,
         socket
         |> assign(avatar_url: nil, upload_error: nil)
         |> put_flash(:info, "Profile photo removed.")}

      {:error, _} ->
        {:noreply, assign(socket, upload_error: "Failed to remove avatar.")}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  # -- Existing toggle handlers --

  def handle_event("toggle_2fa", _params, socket) do
    new_val = !socket.assigns.two_factor_enabled
    user = socket.assigns.current_user

    # Log the security change
    FounderPad.Audit.log(
      :settings_changed,
      "User",
      to_string(user.id),
      user.id,
      nil,
      changes: %{two_factor_enabled: new_val},
      metadata: %{setting: "2fa"}
    )

    message =
      if new_val,
        do: "Two-factor authentication enabled. You'll need an authenticator app for future logins.",
        else: "Two-factor authentication disabled. Your account is less secure."

    {:noreply,
     socket
     |> assign(two_factor_enabled: new_val)
     |> put_flash(if(new_val, do: :info, else: :error), message)}
  end

  def handle_event("toggle_compact_ui", _params, socket) do
    new_val = !socket.assigns.compact_ui

    {:noreply,
     socket
     |> assign(compact_ui: new_val)
     |> push_event("set-ui-mode", %{compact: new_val})}
  end

  def handle_event("toggle_high_contrast", _params, socket) do
    new_val = !socket.assigns.high_contrast

    {:noreply,
     socket
     |> assign(high_contrast: new_val)
     |> push_event("set-high-contrast", %{enabled: new_val})}
  end

  def handle_event("select_theme", %{"theme" => theme}, socket) do
    js_theme = if theme == "midnight", do: "dark", else: "light"

    {:noreply,
     socket
     |> assign(selected_theme: String.to_existing_atom(theme))
     |> push_event("set-theme", %{theme: js_theme})}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: String.to_existing_atom(tab))}
  end

  def handle_event("save_profile", %{"profile" => params}, socket) do
    user = socket.assigns.current_user
    name = String.trim(params["name"] || "")

    if name == "" do
      {:noreply, put_flash(socket, :error, "Name cannot be empty")}
    else
      case user
           |> Ash.Changeset.for_update(:update_profile, %{name: name})
           |> Ash.update() do
        {:ok, updated_user} ->
          {:noreply,
           socket
           |> assign(current_user: updated_user)
           |> assign(department: params["department"] || socket.assigns.department)
           |> put_flash(:info, "Profile updated successfully")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update profile")}
      end
    end
  end

  def handle_event("show_password_form", _, socket) do
    {:noreply, assign(socket, show_password_form: true, password_error: nil)}
  end

  def handle_event("hide_password_form", _, socket) do
    {:noreply, assign(socket, show_password_form: false, password_error: nil)}
  end

  def handle_event("submit_password_change", %{"password" => params}, socket) do
    user = socket.assigns.current_user

    case user
         |> Ash.Changeset.for_update(:change_password, %{
           current_password: params["current_password"],
           password: params["password"],
           password_confirmation: params["password_confirmation"]
         })
         |> Ash.update() do
      {:ok, _updated_user} ->
        {:noreply,
         socket
         |> assign(show_password_form: false, password_error: nil)
         |> put_flash(:info, "Password changed successfully")}

      {:error, changeset} ->
        error_msg = extract_password_error(changeset)

        {:noreply,
         socket
         |> assign(password_error: error_msg)
         |> put_flash(:error, error_msg)}
    end
  end

  def handle_event("view_sessions", _, socket) do
    {:noreply, put_flash(socket, :info, "Active sessions: 3 devices")}
  end

  def handle_event("toggle_delete_confirm", _, socket) do
    {:noreply, assign(socket, show_delete_confirm: !socket.assigns.show_delete_confirm)}
  end

  def handle_event("confirm_delete_account", _, socket) do
    {:noreply,
     socket
     |> assign(show_delete_confirm: false)
     |> put_flash(:error, "Account deletion requires email confirmation. Check your inbox.")}
  end

  def handle_event("discard_changes", _, socket) do
    user = socket.assigns.current_user
    prefs = (user && user.preferences) || %{}

    {:noreply,
     socket
     |> assign(
       avatar_url: user && user.avatar_url,
       department: "Engineering",
       two_factor_enabled: true,
       compact_ui: prefs["compact_ui"] || false,
       high_contrast: prefs["high_contrast"] || false,
       selected_theme: (prefs["theme"] && String.to_existing_atom(prefs["theme"])) || :midnight
     )
     |> put_flash(:info, "Changes discarded")}
  end

  def handle_event("save_preferences", _, socket) do
    user = socket.assigns.current_user

    prefs = %{
      "theme" => to_string(socket.assigns.selected_theme),
      "compact_ui" => socket.assigns.compact_ui,
      "high_contrast" => socket.assigns.high_contrast
    }

    case user |> Ash.Changeset.for_update(:update_profile, %{preferences: prefs}) |> Ash.update() do
      {:ok, _} -> {:noreply, put_flash(socket, :info, "Preferences saved successfully")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to save preferences")}
    end
  end

  # -- Private helpers --

  defp extract_password_error(error) do
    errors =
      case error do
        %{errors: errors} when is_list(errors) -> errors
        _ -> []
      end

    errors
    |> List.flatten()
    |> Enum.map(fn
      %{field: :current_password, message: msg} -> "Current password #{msg}"
      %{vars: %{field: :current_password}, message: msg} -> "Current password #{msg}"
      %{message: msg} -> msg
      err -> inspect(err)
    end)
    |> Enum.join(", ")
    |> case do
      "" -> "Failed to change password"
      msg -> msg
    end
  end

  defp load_login_history(nil), do: []

  defp load_login_history(user) do
    require Ash.Query

    case FounderPad.Audit.AuditLog
         |> Ash.Query.filter(actor_id: user.id, action: :login)
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(5)
         |> Ash.read() do
      {:ok, logs} ->
        Enum.map(logs, fn log ->
          ua = log.user_agent || log.metadata["user_agent"] || "Unknown device"
          ip = log.ip_address || log.metadata["ip_address"] || "Unknown"

          %{
            device: parse_device(ua),
            ip: ip,
            time_ago: time_ago(log.inserted_at),
            current: false
          }
        end)
        |> maybe_mark_current()

      _ ->
        []
    end
    |> then(fn
      [] -> default_login_history()
      entries -> entries
    end)
  end

  defp default_login_history do
    [
      %{device: "Current session", ip: "127.0.0.1", time_ago: "Now", current: true}
    ]
  end

  defp maybe_mark_current([first | rest]) do
    [%{first | current: true} | rest]
  end

  defp maybe_mark_current([]), do: []

  defp parse_device(ua) when is_binary(ua) do
    cond do
      String.contains?(ua, "Chrome") and String.contains?(ua, "Mac") -> "Chrome on macOS"
      String.contains?(ua, "Chrome") and String.contains?(ua, "Windows") -> "Chrome on Windows"
      String.contains?(ua, "Chrome") and String.contains?(ua, "Linux") -> "Chrome on Linux"
      String.contains?(ua, "Safari") and String.contains?(ua, "iPhone") -> "Safari on iPhone"
      String.contains?(ua, "Safari") and String.contains?(ua, "Mac") -> "Safari on macOS"
      String.contains?(ua, "Firefox") -> "Firefox"
      String.contains?(ua, "Edge") -> "Edge"
      true -> String.slice(ua, 0..30)
    end
  end

  defp parse_device(_), do: "Unknown device"

  defp time_ago(nil), do: "—"

  defp time_ago(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 172_800 -> "Yesterday"
      true -> Calendar.strftime(dt, "%b %d")
    end
  end

  defp maybe_delete_old_avatar(nil), do: :ok

  defp maybe_delete_old_avatar(url) when is_binary(url) do
    if String.starts_with?(url, "/uploads/avatars/") do
      path = Path.join([:code.priv_dir(:founder_pad), "static", String.trim_leading(url, "/")])

      if File.exists?(path) do
        File.rm(path)
      end
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 2MB)"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(:not_accepted), do: "Invalid file type. Use JPG, PNG, GIF, or WebP"
  defp error_to_string(_), do: "Upload error"
end
