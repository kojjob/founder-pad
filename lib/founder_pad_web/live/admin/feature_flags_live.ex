defmodule FounderPadWeb.Admin.FeatureFlagsLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    flags = load_flags(socket.assigns.current_user)

    {:ok,
     assign(socket,
       page_title: "Feature Flags \u2014 Admin",
       active_nav: :admin_flags,
       flags: flags
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
            Feature Flags
          </h1>
          <p class="text-on-surface-variant mt-2">
            Toggle feature flags to control feature availability across the platform.
          </p>
        </div>
      </div>

      <div class="bg-surface-container rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Key
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Name
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Description
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Required Plan
              </th>
              <th class="text-center px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Enabled
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={flag <- @flags}
              class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
            >
              <td class="px-6 py-4">
                <code class="text-sm font-mono text-on-surface bg-surface-container-highest px-2 py-0.5 rounded">
                  {flag.key}
                </code>
              </td>
              <td class="px-6 py-4 font-medium text-on-surface">
                {flag.name}
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {flag.description || "\u2014"}
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {flag.required_plan || "\u2014"}
              </td>
              <td class="px-6 py-4 text-center">
                <button phx-click="toggle" phx-value-id={flag.id} class="inline-flex items-center">
                  <span :if={flag.enabled} class="material-symbols-outlined text-3xl text-green-600">
                    toggle_on
                  </span>
                  <span
                    :if={!flag.enabled}
                    class="material-symbols-outlined text-3xl text-neutral-400"
                  >
                    toggle_off
                  </span>
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <div
          :if={@flags == []}
          class="px-6 py-16 text-center text-on-surface-variant"
        >
          <span class="material-symbols-outlined text-4xl opacity-30 block mb-2">flag</span>
          <p>No feature flags found.</p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    flag = Ash.get!(FounderPad.FeatureFlags.FeatureFlag, id)

    flag
    |> Ash.Changeset.for_update(:toggle, %{})
    |> Ash.update!()

    {:noreply,
     socket
     |> put_flash(:info, "Flag toggled.")
     |> assign(flags: load_flags(socket.assigns.current_user))}
  end

  defp load_flags(_user) do
    FounderPad.FeatureFlags.FeatureFlag
    |> Ash.Query.sort(key: :asc)
    |> Ash.read!()
  end
end
