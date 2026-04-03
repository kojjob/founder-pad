defmodule FounderPadWeb.Admin.AdminDashboardLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    admin = socket.assigns.current_user

    user_count =
      FounderPad.Accounts.User
      |> Ash.Query.for_read(:list_all, %{}, actor: admin)
      |> Ash.read!(actor: admin)
      |> length()

    org_count =
      FounderPad.Accounts.Organisation
      |> Ash.read!()
      |> length()

    active_keys =
      FounderPad.ApiKeys.ApiKey
      |> Ash.Query.for_read(:active)
      |> Ash.read!()
      |> length()

    flag_count =
      FounderPad.FeatureFlags.FeatureFlag
      |> Ash.read!()
      |> length()

    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       active_nav: :admin_dashboard,
       user_count: user_count,
       org_count: org_count,
       active_key_count: active_keys,
       flag_count: flag_count
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h1 class="font-heading text-2xl font-bold text-on-surface">Admin Dashboard</h1>
        <p class="text-on-surface-variant mt-1">System overview and management.</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
        <a
          href="/admin/users"
          class="bg-white rounded-2xl border border-neutral-200/60 p-6 hover:shadow-md transition-shadow"
        >
          <div class="flex items-center gap-3 mb-3">
            <span class="material-symbols-outlined text-primary">group</span>
            <p class="text-sm text-on-surface-variant">Users</p>
          </div>
          <p class="text-3xl font-heading font-bold text-on-surface">{@user_count}</p>
        </a>
        <a
          href="/admin/organisations"
          class="bg-white rounded-2xl border border-neutral-200/60 p-6 hover:shadow-md transition-shadow"
        >
          <div class="flex items-center gap-3 mb-3">
            <span class="material-symbols-outlined text-primary">corporate_fare</span>
            <p class="text-sm text-on-surface-variant">Organisations</p>
          </div>
          <p class="text-3xl font-heading font-bold text-on-surface">{@org_count}</p>
        </a>
        <div class="bg-white rounded-2xl border border-neutral-200/60 p-6">
          <div class="flex items-center gap-3 mb-3">
            <span class="material-symbols-outlined text-primary">key</span>
            <p class="text-sm text-on-surface-variant">Active API Keys</p>
          </div>
          <p class="text-3xl font-heading font-bold text-on-surface">{@active_key_count}</p>
        </div>
        <a
          href="/admin/feature-flags"
          class="bg-white rounded-2xl border border-neutral-200/60 p-6 hover:shadow-md transition-shadow"
        >
          <div class="flex items-center gap-3 mb-3">
            <span class="material-symbols-outlined text-primary">toggle_on</span>
            <p class="text-sm text-on-surface-variant">Feature Flags</p>
          </div>
          <p class="text-3xl font-heading font-bold text-on-surface">{@flag_count}</p>
        </a>
      </div>
    </div>
    """
  end
end
