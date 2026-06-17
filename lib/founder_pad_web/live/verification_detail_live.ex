defmodule FounderPadWeb.VerificationDetailLive do
  @moduledoc "Compliance view: a single verification's status, identity, risk and consent."
  use FounderPadWeb, :live_view

  require Ash.Query

  def mount(%{"id" => id}, _session, socket) do
    org = current_org(socket.assigns.current_user)

    case load_verification(id, org) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Verification not found.")
         |> push_navigate(to: ~p"/verifications")}

      ivf ->
        {:ok,
         assign(socket,
           page_title: "Verification #{short(ivf.id)}",
           active_nav: :verifications,
           ivf: ivf
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-3xl mx-auto">
      <.link navigate={~p"/verifications"} class="text-sm text-primary hover:underline">
        &larr; Back to verifications
      </.link>

      <header>
        <h1 class="text-3xl font-extrabold font-headline tracking-tight">
          {@ivf.external_id || "Verification"}
        </h1>
        <p class="text-on-surface-variant mt-1 font-mono text-xs">{@ivf.id}</p>
      </header>

      <dl class="grid grid-cols-2 gap-4">
        <.field label="Status" value={@ivf.status} />
        <.field label="Mode" value={@ivf.mode} />
        <.field label="Identity verified" value={@ivf.identity_verified} />
        <.field label="Match level" value={@ivf.match_level} />
      </dl>

      <section class="bg-surface-container rounded-lg p-5 space-y-3">
        <h2 class="text-sm font-bold uppercase text-on-surface-variant">Risk</h2>
        <div class="flex items-center gap-6">
          <div>
            <p class="text-xs text-on-surface-variant">Level</p>
            <p class="text-lg font-bold">{@ivf.risk_level || "—"}</p>
          </div>
          <div>
            <p class="text-xs text-on-surface-variant">Score</p>
            <p class="text-lg font-bold">{@ivf.risk_score || "—"}</p>
          </div>
        </div>
        <div :if={@ivf.reason_codes != []} class="flex flex-wrap gap-1.5">
          <span
            :for={code <- @ivf.reason_codes}
            class="px-2 py-0.5 rounded bg-surface-container-high text-xs font-mono"
          >
            {code}
          </span>
        </div>
      </section>

      <section class="bg-surface-container rounded-lg p-5">
        <h2 class="text-sm font-bold uppercase text-on-surface-variant mb-2">Consent</h2>
        <p class="font-mono text-xs">{@ivf.consent_receipt_id || "No consent receipt (test mode)"}</p>
      </section>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp field(assigns) do
    ~H"""
    <div class="bg-surface-container rounded-lg p-4">
      <dt class="text-xs uppercase text-on-surface-variant">{@label}</dt>
      <dd class="text-lg font-bold mt-1">{to_string(@value)}</dd>
    </div>
    """
  end

  defp load_verification(_id, nil), do: nil

  defp load_verification(id, org) do
    case Ash.get(FounderPad.Compliance.IndividualVerification, id, authorize?: false) do
      {:ok, %{organisation_id: org_id} = ivf} when org_id == org.id -> ivf
      _ -> nil
    end
  end

  defp current_org(user) do
    FounderPad.Accounts.Membership
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.load([:organisation])
    |> Ash.read!()
    |> case do
      [m | _] -> m.organisation
      [] -> nil
    end
  end

  defp short(id), do: String.slice(id, 0..7)
end
