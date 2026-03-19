defmodule FounderPadWeb.OnboardingLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Welcome", step: 1, total_steps: 4)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-background p-4">
      <div class="w-full max-w-lg space-y-8">
        <%!-- Progress --%>
        <div class="flex items-center gap-2">
          <div
            :for={i <- 1..@total_steps}
            class={[
              "h-1 flex-1 rounded-full transition-colors",
              if(i <= @step, do: "bg-primary", else: "bg-surface-container-highest")
            ]}
          >
          </div>
        </div>
        <p class="text-xs font-mono text-on-surface-variant text-center">
          Step {@step} of {@total_steps}
        </p>

        <%!-- Step 1: Create Organisation --%>
        <div :if={@step == 1} class="space-y-6 text-center">
          <span class="material-symbols-outlined text-5xl text-primary">apartment</span>
          <h1 class="text-3xl font-extrabold font-headline">Create Your Organisation</h1>
          <p class="text-on-surface-variant">
            This is your workspace where your team and agents live.
          </p>
          <input
            type="text"
            placeholder="Organisation name"
            class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface text-center focus:ring-2 focus:ring-primary"
          />
        </div>

        <%!-- Step 2: Invite Team --%>
        <div :if={@step == 2} class="space-y-6 text-center">
          <span class="material-symbols-outlined text-5xl text-primary">group_add</span>
          <h1 class="text-3xl font-extrabold font-headline">Invite Your Team</h1>
          <p class="text-on-surface-variant">
            Add team members by email. You can always do this later.
          </p>
          <input
            type="email"
            placeholder="teammate@company.com"
            class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface text-center focus:ring-2 focus:ring-primary"
          />
        </div>

        <%!-- Step 3: Create First Agent --%>
        <div :if={@step == 3} class="space-y-6 text-center">
          <span class="material-symbols-outlined text-5xl text-primary">smart_toy</span>
          <h1 class="text-3xl font-extrabold font-headline">Create Your First Agent</h1>
          <p class="text-on-surface-variant">Choose a template to get started quickly.</p>
          <div class="grid grid-cols-2 gap-3 text-left">
            <div
              :for={
                {name, icon} <- [
                  {"Research", "science"},
                  {"Code Review", "code"},
                  {"Writing", "edit_note"},
                  {"Custom", "tune"}
                ]
              }
              class="bg-surface-container p-4 rounded-lg cursor-pointer hover:bg-surface-container-high transition-colors border border-transparent hover:border-primary/20"
            >
              <span class="material-symbols-outlined text-primary mb-2">{icon}</span>
              <p class="text-sm font-semibold">{name}</p>
            </div>
          </div>
        </div>

        <%!-- Step 4: All Set --%>
        <div :if={@step == 4} class="space-y-6 text-center">
          <span class="material-symbols-outlined text-5xl text-primary">rocket_launch</span>
          <h1 class="text-3xl font-extrabold font-headline">You're All Set!</h1>
          <p class="text-on-surface-variant">
            Your workspace is ready. Let's see your agent in action.
          </p>
        </div>

        <%!-- Navigation --%>
        <div class="flex justify-between">
          <button
            :if={@step > 1}
            phx-click="prev_step"
            class="px-4 py-2 text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
          >
            Back
          </button>
          <div :if={@step == 1}></div>
          <button
            phx-click={if @step < @total_steps, do: "next_step", else: "complete"}
            class="bg-gradient-to-br from-primary to-primary-container text-on-primary-fixed font-semibold px-6 py-2.5 rounded-lg text-sm"
          >
            {if @step < @total_steps, do: "Continue", else: "Go to Dashboard"}
          </button>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("next_step", _, socket) do
    {:noreply, update(socket, :step, &min(&1 + 1, socket.assigns.total_steps))}
  end

  def handle_event("prev_step", _, socket) do
    {:noreply, update(socket, :step, &max(&1 - 1, 1))}
  end

  def handle_event("complete", _, socket) do
    {:noreply, push_navigate(socket, to: "/dashboard")}
  end
end
