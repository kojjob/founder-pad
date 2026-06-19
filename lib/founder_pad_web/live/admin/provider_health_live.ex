defmodule FounderPadWeb.Admin.ProviderHealthLive do
  @moduledoc """
  Internal ops view (admin only): the configured compliance provider seams, their
  sandbox/live mode, and a count of failed background jobs (story O1).
  """
  use FounderPadWeb, :live_view

  import Ecto.Query

  alias FounderPad.Compliance.{AmlScreening, KybVerifications, Storage, Verifications}
  alias FounderPad.Repo

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Provider Health",
       active_nav: :admin,
       providers: providers(),
       failed_jobs: failed_job_count()
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-4xl mx-auto">
      <header>
        <div class="flex items-center gap-2 text-xs font-mono text-on-surface-variant/60 uppercase tracking-widest mb-2">
          <span class="material-symbols-outlined text-sm text-primary">monitoring</span> Operations
        </div>
        <h1 class="text-4xl font-extrabold font-headline tracking-tight">Provider Health</h1>
        <p class="text-on-surface-variant mt-1">
          Configured provider seams and background-job health.
        </p>
      </header>

      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-surface-container rounded-lg p-4">
          <dt class="text-xs uppercase text-on-surface-variant">Failed jobs</dt>
          <dd class={[
            "text-2xl font-extrabold mt-1",
            if(@failed_jobs == 0, do: "text-primary", else: "text-error")
          ]}>
            {@failed_jobs}
          </dd>
        </div>
      </div>

      <table class="w-full text-sm">
        <thead class="text-left text-xs uppercase text-on-surface-variant border-b border-outline-variant/20">
          <tr>
            <th class="py-2">Seam</th>
            <th class="py-2">Adapter</th>
            <th class="py-2">Mode</th>
            <th class="py-2">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{label, mod, mode} <- @providers} class="border-b border-outline-variant/10">
            <td class="py-3 font-medium">{label}</td>
            <td class="py-3 font-mono text-xs">{inspect(mod)}</td>
            <td class="py-3">
              <span class={[
                "px-2 py-0.5 rounded text-xs font-bold",
                if(mode == "sandbox",
                  do: "bg-secondary/10 text-secondary",
                  else: "bg-primary/10 text-primary"
                )
              ]}>
                {mode}
              </span>
            </td>
            <td class="py-3 text-primary">operational</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp providers do
    [
      {"Identity", Verifications.provider()},
      {"Liveness", Verifications.liveness_provider()},
      {"KYB", KybVerifications.provider()},
      {"AML", AmlScreening.provider()},
      {"Storage", Storage.adapter()}
    ]
    |> Enum.map(fn {label, mod} -> {label, mod, mode(mod)} end)
  end

  defp mode(mod) do
    if mod |> Atom.to_string() |> String.contains?("Sandbox"), do: "sandbox", else: "live"
  end

  defp failed_job_count do
    Repo.aggregate(from(j in Oban.Job, where: j.state == "discarded"), :count)
  rescue
    _ -> 0
  end
end
