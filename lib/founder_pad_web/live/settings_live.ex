defmodule FounderPadWeb.SettingsLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_nav: :settings, page_title: "Settings", active_tab: :general)}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <h1 class="text-4xl font-extrabold font-headline tracking-tight">Settings</h1>

      <%!-- Tab Navigation --%>
      <div class="flex gap-1 border-b border-outline-variant/10">
        <button
          :for={
            {label, key} <- [{"General", :general}, {"API Keys", :api_keys}, {"Notifications", :notifications}]
          }
          phx-click="switch_tab"
          phx-value-tab={key}
          class={[
            "px-4 py-2.5 text-sm font-medium border-b-2 transition-colors -mb-px",
            if(@active_tab == key,
              do: "border-primary text-primary",
              else: "border-transparent text-on-surface-variant hover:text-on-surface"
            )
          ]}
        >
          {label}
        </button>
      </div>

      <%!-- General Tab --%>
      <div :if={@active_tab == :general} class="space-y-8">
        <div class="bg-surface-container rounded-lg p-6 space-y-6">
          <h3 class="font-bold text-lg">Organisation Settings</h3>
          <div class="grid grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                Organisation Name
              </label>
              <input
                type="text"
                value="FounderPad Demo"
                class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                Billing Email
              </label>
              <input
                type="email"
                value="billing@company.com"
                class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary"
              />
            </div>
          </div>
          <button class="bg-gradient-to-br from-primary to-primary-container text-on-primary-fixed font-semibold px-4 py-2 rounded-lg text-sm">
            Save Changes
          </button>
        </div>

        <div class="bg-surface-container rounded-lg p-6 space-y-6">
          <h3 class="font-bold text-lg">Personal Settings</h3>
          <div class="grid grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                Display Name
              </label>
              <input
                type="text"
                value="Sarah Chen"
                class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-on-surface-variant mb-1.5">Email</label>
              <input
                type="email"
                value="sarah@company.com"
                class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-2.5 text-sm text-on-surface focus:ring-1 focus:ring-primary"
              />
            </div>
          </div>
        </div>

        <div class="bg-error/5 rounded-lg p-6 border border-error/20">
          <h3 class="font-bold text-lg text-error mb-2">Danger Zone</h3>
          <p class="text-sm text-on-surface-variant mb-4">
            Permanently delete this organisation and all associated data.
          </p>
          <button class="bg-error/10 text-error px-4 py-2 rounded-lg text-sm font-medium hover:bg-error/20 transition-colors">
            Delete Organisation
          </button>
        </div>
      </div>

      <%!-- API Keys Tab --%>
      <div :if={@active_tab == :api_keys} class="space-y-6">
        <div class="flex justify-between items-center">
          <p class="text-on-surface-variant">Manage API keys for programmatic access</p>
          <button class="bg-gradient-to-br from-primary to-primary-container text-on-primary-fixed font-semibold px-4 py-2 rounded-lg text-sm">
            <span class="flex items-center gap-2">
              <span class="material-symbols-outlined text-lg">add</span> New Key
            </span>
          </button>
        </div>
        <div class="bg-surface-container rounded-lg overflow-hidden">
          <div class="grid grid-cols-12 gap-4 px-6 py-3 text-xs font-mono uppercase tracking-widest text-on-surface-variant border-b border-outline-variant/10">
            <div class="col-span-3">Name</div>
            <div class="col-span-4">Key</div>
            <div class="col-span-2">Created</div>
            <div class="col-span-2">Last Used</div>
            <div class="col-span-1"></div>
          </div>
          <div class="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-surface-container-high/50">
            <div class="col-span-3 text-sm font-semibold">Production</div>
            <div class="col-span-4 font-mono text-sm text-on-surface-variant">
              fp_live_••••••••••••a1b2
            </div>
            <div class="col-span-2 text-sm text-on-surface-variant font-mono">Jan 15</div>
            <div class="col-span-2 text-sm text-on-surface-variant font-mono">2m ago</div>
            <div class="col-span-1 text-right">
              <button class="text-error text-sm hover:underline">Revoke</button>
            </div>
          </div>
          <div class="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-surface-container-high/50">
            <div class="col-span-3 text-sm font-semibold">Development</div>
            <div class="col-span-4 font-mono text-sm text-on-surface-variant">
              fp_test_••••••••••••c3d4
            </div>
            <div class="col-span-2 text-sm text-on-surface-variant font-mono">Feb 20</div>
            <div class="col-span-2 text-sm text-on-surface-variant font-mono">1h ago</div>
            <div class="col-span-1 text-right">
              <button class="text-error text-sm hover:underline">Revoke</button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Notifications Tab --%>
      <div :if={@active_tab == :notifications} class="space-y-6">
        <div class="bg-surface-container rounded-lg p-6 space-y-6">
          <h3 class="font-bold text-lg">Email Notifications</h3>
          <div class="space-y-4">
            <.toggle_row
              label="Agent run completed"
              description="Get notified when an agent finishes a task"
              enabled={true}
            />
            <.toggle_row
              label="Agent run failed"
              description="Alert when an agent encounters an error"
              enabled={true}
            />
            <.toggle_row
              label="Billing updates"
              description="Invoice and payment notifications"
              enabled={true}
            />
            <.toggle_row
              label="Team changes"
              description="New members, role changes, removals"
              enabled={false}
            />
            <.toggle_row
              label="Weekly digest"
              description="Summary of workspace activity"
              enabled={false}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp toggle_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-2">
      <div>
        <p class="text-sm font-medium">{@label}</p>
        <p class="text-xs text-on-surface-variant">{@description}</p>
      </div>
      <button class={[
        "w-11 h-6 rounded-full transition-colors relative",
        if(@enabled, do: "bg-primary", else: "bg-surface-container-highest")
      ]}>
        <span class={[
          "absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform",
          if(@enabled, do: "left-[22px]", else: "left-0.5")
        ]}>
        </span>
      </button>
    </div>
    """
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: String.to_existing_atom(tab))}
  end
end
