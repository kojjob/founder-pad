defmodule FounderPadWeb.OnboardingLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  @templates %{
    "research" => %{
      name: "Research Assistant",
      description: "Deep research across documents and web sources.",
      system_prompt: "You are a meticulous research assistant. Analyze topics thoroughly, cite sources when possible, and present findings in a clear, structured format.",
      temperature: 0.5,
      max_tokens: 4096
    },
    "code_review" => %{
      name: "Code Reviewer",
      description: "Automated PR reviews with security vulnerability detection.",
      system_prompt: "You are an expert code reviewer. Review code for bugs, security vulnerabilities, performance issues, and adherence to best practices.",
      temperature: 0.3,
      max_tokens: 8192
    },
    "writing" => %{
      name: "Content Writer",
      description: "Generate blog posts, documentation, and marketing copy.",
      system_prompt: "You are a skilled content writer. Create engaging, well-structured content tailored to the audience.",
      temperature: 0.8,
      max_tokens: 4096
    },
    "custom" => %{
      name: "Custom Agent",
      description: "Start from scratch with your own configuration.",
      system_prompt: "You are a helpful assistant.",
      temperature: 0.7,
      max_tokens: 4096
    }
  }

  def mount(_params, session, socket) do
    current_user =
      case session["user_token"] do
        nil -> nil
        token ->
          case AshAuthentication.subject_to_user(token, FounderPad.Accounts.User) do
            {:ok, user} -> user
            _ -> nil
          end
      end

    {:ok,
     assign(socket,
       page_title: "Welcome",
       step: 1,
       total_steps: 4,
       current_user: current_user,
       org_name: "",
       invite_emails: [],
       invite_input: "",
       selected_template: nil,
       templates: @templates,
       error: nil
     )}
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

        <%!-- Error display --%>
        <div :if={@error} class="bg-error/10 text-error text-sm font-medium p-4 rounded-xl text-center">
          {@error}
        </div>

        <%!-- Step 1: Create Organisation --%>
        <div :if={@step == 1} class="space-y-6 text-center">
          <span class="material-symbols-outlined text-5xl text-primary">apartment</span>
          <h1 class="text-3xl font-extrabold font-headline">Create Your Organisation</h1>
          <p class="text-on-surface-variant">
            This is your workspace where your team and agents live.
          </p>
          <input
            type="text"
            name="org_name"
            value={@org_name}
            placeholder="Organisation name"
            phx-change="update_org_name"
            phx-debounce="300"
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
          <form phx-submit="add_invite" class="flex gap-2">
            <input
              type="email"
              name="email"
              value={@invite_input}
              placeholder="teammate@company.com"
              class="flex-1 bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface text-center focus:ring-2 focus:ring-primary"
            />
            <button type="submit" class="primary-gradient px-4 py-2.5 rounded-lg text-sm font-semibold">
              Add
            </button>
          </form>
          <div :if={@invite_emails != []} class="flex flex-wrap gap-2 justify-center">
            <span
              :for={email <- @invite_emails}
              class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-primary/10 text-primary text-xs font-medium rounded-full"
            >
              {email}
              <button
                type="button"
                phx-click="remove_invite"
                phx-value-email={email}
                class="hover:text-error transition-colors"
              >
                <span class="material-symbols-outlined text-[14px]">close</span>
              </button>
            </span>
          </div>
        </div>

        <%!-- Step 3: Create First Agent --%>
        <div :if={@step == 3} class="space-y-6 text-center">
          <span class="material-symbols-outlined text-5xl text-primary">smart_toy</span>
          <h1 class="text-3xl font-extrabold font-headline">Create Your First Agent</h1>
          <p class="text-on-surface-variant">Choose a template to get started quickly.</p>
          <div class="grid grid-cols-2 gap-3 text-left">
            <button
              :for={{key, tmpl} <- @templates |> Enum.sort()}
              type="button"
              phx-click="select_template"
              phx-value-template={key}
              class={[
                "bg-surface-container p-4 rounded-lg cursor-pointer transition-all border-2 text-left",
                if(@selected_template == key,
                  do: "border-primary shadow-md bg-primary/5",
                  else: "border-transparent hover:bg-surface-container-high hover:border-primary/20"
                )
              ]}
            >
              <span class="material-symbols-outlined text-primary mb-2">{template_icon(key)}</span>
              <p class="text-sm font-semibold">{tmpl.name}</p>
            </button>
          </div>
        </div>

        <%!-- Step 4: All Set --%>
        <div :if={@step == 4} class="space-y-6 text-center">
          <span class="material-symbols-outlined text-5xl text-primary">rocket_launch</span>
          <h1 class="text-3xl font-extrabold font-headline">You're All Set!</h1>
          <p class="text-on-surface-variant">
            Your workspace is ready. Let's see your agent in action.
          </p>
          <div class="space-y-3 text-sm text-on-surface-variant">
            <p :if={@org_name != ""}>Organisation: <strong class="text-on-surface">{@org_name}</strong></p>
            <p :if={@invite_emails != []}>Invites: <strong class="text-on-surface">{length(@invite_emails)} team member(s)</strong></p>
            <p :if={@selected_template}>
              Agent: <strong class="text-on-surface">{@templates[@selected_template].name}</strong>
            </p>
          </div>
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
            class="primary-gradient font-semibold px-6 py-2.5 rounded-lg text-sm"
          >
            {if @step < @total_steps, do: "Continue", else: "Go to Dashboard"}
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ── Events ──

  def handle_event("next_step", _, socket) do
    {:noreply, update(socket, :step, &min(&1 + 1, socket.assigns.total_steps))}
  end

  def handle_event("prev_step", _, socket) do
    {:noreply, update(socket, :step, &max(&1 - 1, 1))}
  end

  def handle_event("update_org_name", %{"org_name" => name}, socket) do
    {:noreply, assign(socket, org_name: name)}
  end

  def handle_event("add_invite", %{"email" => email}, socket) do
    email = String.trim(email)

    if email != "" and email not in socket.assigns.invite_emails do
      {:noreply, assign(socket, invite_emails: socket.assigns.invite_emails ++ [email], invite_input: "")}
    else
      {:noreply, assign(socket, invite_input: "")}
    end
  end

  def handle_event("remove_invite", %{"email" => email}, socket) do
    {:noreply, assign(socket, invite_emails: List.delete(socket.assigns.invite_emails, email))}
  end

  def handle_event("select_template", %{"template" => key}, socket) do
    if Map.has_key?(@templates, key) do
      {:noreply, assign(socket, selected_template: key)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("complete", _, socket) do
    user = socket.assigns.current_user
    org_name = socket.assigns.org_name
    selected = socket.assigns.selected_template

    cond do
      is_nil(user) ->
        {:noreply, assign(socket, error: "You must be logged in to complete onboarding.")}

      org_name == "" ->
        {:noreply, assign(socket, error: "Please provide an organisation name.", step: 1)}

      true ->
        case create_workspace(user, org_name, selected) do
          {:ok, _org, agent} when not is_nil(agent) ->
            {:noreply,
             socket
             |> put_flash(:info, "Welcome to FounderPad!")
             |> push_navigate(to: "/agents/#{agent.id}")}

          {:ok, _org, nil} ->
            {:noreply,
             socket
             |> put_flash(:info, "Welcome to FounderPad!")
             |> push_navigate(to: "/dashboard")}

          {:error, reason} ->
            {:noreply, assign(socket, error: "Setup failed: #{reason}")}
        end
    end
  end

  # ── Helpers ──

  defp create_workspace(user, org_name, selected_template) do
    try do
      # Create Organisation
      {:ok, org} =
        FounderPad.Accounts.Organisation
        |> Ash.Changeset.for_create(:create, %{name: org_name})
        |> Ash.create()

      # Create Membership (owner)
      {:ok, _membership} =
        FounderPad.Accounts.Membership
        |> Ash.Changeset.for_create(:create, %{
          role: :owner,
          user_id: user.id,
          organisation_id: org.id
        })
        |> Ash.create()

      # Create Agent from template (if selected)
      agent =
        if selected_template && Map.has_key?(@templates, selected_template) do
          tmpl = @templates[selected_template]

          {:ok, agent} =
            FounderPad.AI.Agent
            |> Ash.Changeset.for_create(:create, %{
              name: tmpl.name,
              description: tmpl.description,
              system_prompt: tmpl.system_prompt,
              model: "claude-sonnet-4-20250514",
              provider: :anthropic,
              temperature: tmpl.temperature,
              max_tokens: tmpl.max_tokens,
              organisation_id: org.id
            })
            |> Ash.create()

          agent
        end

      {:ok, org, agent}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp template_icon("research"), do: "science"
  defp template_icon("code_review"), do: "code"
  defp template_icon("writing"), do: "edit_note"
  defp template_icon("custom"), do: "tune"
  defp template_icon(_), do: "smart_toy"
end
