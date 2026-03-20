defmodule FounderPadWeb.OnboardingLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  @templates %{
    "research" => %{
      name: "Research Assistant",
      description: "Deep research across documents and web sources with citation tracking.",
      system_prompt:
        "You are a meticulous research assistant. Analyze topics thoroughly, cite sources when possible, and present findings in a clear, structured format. Always distinguish between established facts and your analysis.",
      temperature: 0.5,
      max_tokens: 4096
    },
    "code_review" => %{
      name: "Code Reviewer",
      description:
        "Automated PR reviews with security vulnerability detection and best practices.",
      system_prompt:
        "You are an expert code reviewer. Review code for bugs, security vulnerabilities, performance issues, and adherence to best practices. Provide specific, actionable feedback with code examples.",
      temperature: 0.3,
      max_tokens: 8192
    },
    "content" => %{
      name: "Content Writer",
      description: "Generate high-quality blog posts, documentation, and marketing copy.",
      system_prompt:
        "You are a skilled content writer. Create engaging, well-structured content tailored to the audience. Focus on clarity, proper tone, and SEO best practices when applicable.",
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
    current_user = load_user_from_session(session)

    {:ok,
     assign(socket,
       page_title: "Welcome",
       step: 1,
       total_steps: 4,
       current_user: current_user,
       org_name: "",
       invite_emails: [],
       selected_template: nil
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
            value={@org_name}
            phx-change="update_org_name"
            phx-debounce="300"
            name="org_name"
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
              placeholder="teammate@company.com"
              class="flex-1 bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface text-center focus:ring-2 focus:ring-primary"
            />
            <button
              type="submit"
              class="px-4 py-2 bg-primary text-on-primary rounded-lg text-sm font-medium"
            >
              Add
            </button>
          </form>
          <div :if={@invite_emails != []} class="flex flex-wrap gap-2 justify-center">
            <span
              :for={email <- @invite_emails}
              class="inline-flex items-center gap-1 bg-surface-container px-3 py-1 rounded-full text-sm text-on-surface"
            >
              {email}
              <button
                type="button"
                phx-click="remove_invite"
                phx-value-email={email}
                class="material-symbols-outlined text-sm text-on-surface-variant hover:text-error cursor-pointer"
              >
                close
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
            <div
              :for={
                {key, icon} <- [
                  {"research", "science"},
                  {"code_review", "code"},
                  {"content", "edit_note"},
                  {"custom", "tune"}
                ]
              }
              phx-click="select_template"
              phx-value-template={key}
              class={[
                "bg-surface-container p-4 rounded-lg cursor-pointer hover:bg-surface-container-high transition-colors border-2",
                if(@selected_template == key,
                  do: "border-primary shadow-md",
                  else: "border-transparent hover:border-primary/20"
                )
              ]}
            >
              <span class="material-symbols-outlined text-primary mb-2">{icon}</span>
              <p class="text-sm font-semibold">{template_display_name(key)}</p>
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
          <div class="bg-surface-container rounded-lg p-4 text-left space-y-3">
            <div class="flex items-center gap-2 text-sm">
              <span class="material-symbols-outlined text-primary text-lg">apartment</span>
              <span class="text-on-surface-variant">Organisation:</span>
              <span class="font-semibold text-on-surface">{@org_name}</span>
            </div>
            <div :if={@invite_emails != []} class="flex items-center gap-2 text-sm">
              <span class="material-symbols-outlined text-primary text-lg">group_add</span>
              <span class="text-on-surface-variant">Invites:</span>
              <span class="font-semibold text-on-surface">
                {length(@invite_emails)} team member(s)
              </span>
            </div>
            <div :if={@selected_template} class="flex items-center gap-2 text-sm">
              <span class="material-symbols-outlined text-primary text-lg">smart_toy</span>
              <span class="text-on-surface-variant">Agent:</span>
              <span class="font-semibold text-on-surface">
                {template_display_name(@selected_template)}
              </span>
            </div>
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

    if email != "" && email not in socket.assigns.invite_emails do
      {:noreply, assign(socket, invite_emails: socket.assigns.invite_emails ++ [email])}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_invite", %{"email" => email}, socket) do
    {:noreply,
     assign(socket, invite_emails: Enum.reject(socket.assigns.invite_emails, &(&1 == email)))}
  end

  def handle_event("select_template", %{"template" => template_key}, socket) do
    if Map.has_key?(@templates, template_key) do
      {:noreply, assign(socket, selected_template: template_key)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("complete", _, socket) do
    user = socket.assigns.current_user
    org_name = socket.assigns.org_name
    selected_template = socket.assigns.selected_template

    if is_nil(user) do
      {:noreply, push_navigate(socket, to: "/dashboard")}
    else
      case create_onboarding_resources(user, org_name, selected_template) do
        {:ok, _org, nil} ->
          {:noreply, push_navigate(socket, to: "/dashboard")}

        {:ok, _org, agent} ->
          {:noreply, push_navigate(socket, to: "/agents/#{agent.id}")}

        {:error, _reason} ->
          {:noreply, push_navigate(socket, to: "/dashboard")}
      end
    end
  end

  # ── Private ──

  defp create_onboarding_resources(user, org_name, selected_template) do
    org_name = if org_name == "", do: "My Organisation", else: org_name

    with {:ok, org} <- create_organisation(org_name),
         {:ok, _membership} <- create_membership(user, org) do
      agent = maybe_create_agent(org, selected_template)
      {:ok, org, agent}
    end
  end

  defp create_organisation(name) do
    FounderPad.Accounts.Organisation
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create()
  end

  defp create_membership(user, org) do
    FounderPad.Accounts.Membership
    |> Ash.Changeset.for_create(:create, %{
      role: :owner,
      user_id: user.id,
      organisation_id: org.id
    })
    |> Ash.create()
  end

  defp maybe_create_agent(_org, nil), do: nil

  defp maybe_create_agent(org, template_key) do
    case Map.get(@templates, template_key) do
      nil ->
        nil

      tmpl ->
        case FounderPad.AI.Agent
             |> Ash.Changeset.for_create(:create, %{
               name: tmpl.name,
               description: tmpl.description,
               system_prompt: tmpl.system_prompt,
               temperature: tmpl.temperature,
               max_tokens: tmpl.max_tokens,
               organisation_id: org.id
             })
             |> Ash.create() do
          {:ok, agent} -> agent
          {:error, _} -> nil
        end
    end
  end

  defp load_user_from_session(%{"user_token" => token}) when is_binary(token) do
    case AshAuthentication.subject_to_user(token, FounderPad.Accounts.User) do
      {:ok, user} -> user
      _ -> nil
    end
  end

  defp load_user_from_session(_), do: nil

  defp template_display_name(key) do
    case Map.get(@templates, key) do
      nil -> key
      tmpl -> tmpl.name
    end
  end
end
