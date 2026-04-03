defmodule FounderPadWeb.Admin.OrganisationsLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    orgs =
      FounderPad.Accounts.Organisation
      |> Ash.Query.load([:memberships])
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!()

    {:ok,
     assign(socket,
       page_title: "Organisations \u2014 Admin",
       active_nav: :admin_orgs,
       orgs: orgs
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-6xl mx-auto">
      <div class="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">
            Organisations
          </h1>
          <p class="text-on-surface-variant mt-2">
            View and manage all organisations on the platform.
          </p>
        </div>
      </div>

      <div class="bg-surface-container rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-outline-variant/30">
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Name
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Slug
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Members
              </th>
              <th class="text-left px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Created
              </th>
              <th class="text-right px-6 py-4 text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={org <- @orgs}
              class="border-b border-outline-variant/10 hover:bg-surface-container-highest/50 transition-colors"
            >
              <td class="px-6 py-4">
                <div class="font-medium text-on-surface">{org.name}</div>
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {org.slug}
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {length(org.memberships)}
              </td>
              <td class="px-6 py-4 text-sm text-on-surface-variant">
                {Calendar.strftime(org.inserted_at, "%b %d, %Y")}
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center justify-end gap-2">
                  <span class="text-xs px-3 py-1.5 rounded-md bg-surface-container-highest text-on-surface">
                    {length(org.memberships)} members
                  </span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <div
          :if={@orgs == []}
          class="px-6 py-16 text-center text-on-surface-variant"
        >
          <span class="material-symbols-outlined text-4xl opacity-30 block mb-2">corporate_fare</span>
          <p>No organisations found.</p>
        </div>
      </div>
    </div>
    """
  end
end
