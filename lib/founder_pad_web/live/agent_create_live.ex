defmodule FounderPadWeb.AgentCreateLive do
  use FounderPadWeb, :live_view

  require Ash.Query

  @templates %{
    "research" => %{
      name: "Research Assistant",
      description: "Deep research across documents and web sources with citation tracking.",
      system_prompt: "You are a meticulous research assistant. Analyze topics thoroughly, cite sources when possible, and present findings in a clear, structured format. Always distinguish between established facts and your analysis.",
      temperature: 0.5,
      max_tokens: 4096
    },
    "code_review" => %{
      name: "Code Reviewer",
      description: "Automated PR reviews with security vulnerability detection and best practices.",
      system_prompt: "You are an expert code reviewer. Review code for bugs, security vulnerabilities, performance issues, and adherence to best practices. Provide specific, actionable feedback with code examples.",
      temperature: 0.3,
      max_tokens: 8192
    },
    "content" => %{
      name: "Content Writer",
      description: "Generate high-quality blog posts, documentation, and marketing copy.",
      system_prompt: "You are a skilled content writer. Create engaging, well-structured content tailored to the audience. Focus on clarity, proper tone, and SEO best practices when applicable.",
      temperature: 0.8,
      max_tokens: 4096
    },
    "custom" => %{
      name: "",
      description: "",
      system_prompt: "You are a helpful assistant.",
      temperature: 0.7,
      max_tokens: 4096
    }
  }

  @models_by_provider %{
    "anthropic" => [
      {"Claude Sonnet 4", "claude-sonnet-4-20250514"},
      {"Claude Opus 4", "claude-opus-4-20250514"},
      {"Claude Haiku 3.5", "claude-3-5-haiku-20241022"}
    ],
    "openai" => [
      {"GPT-4o", "gpt-4o"},
      {"GPT-4o Mini", "gpt-4o-mini"},
      {"GPT-4 Turbo", "gpt-4-turbo"}
    ]
  }

  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]
    org = load_user_org(user)

    {:ok,
     assign(socket,
       active_nav: :agents,
       page_title: "Create New Agent",
       org: org,
       selected_template: nil,
       form_data: %{
         "name" => "",
         "description" => "",
         "provider" => "anthropic",
         "model" => "claude-sonnet-4-20250514",
         "system_prompt" => "You are a helpful assistant.",
         "temperature" => "0.7",
         "max_tokens" => "4096"
       },
       models: @models_by_provider["anthropic"],
       error: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-4xl mx-auto">
      <%!-- Header --%>
      <section>
        <div class="flex items-center gap-2 text-sm text-on-surface-variant font-medium mb-3">
          <.link navigate="/agents" class="hover:text-on-surface transition-colors">Agents</.link>
          <span class="material-symbols-outlined text-[14px]">chevron_right</span>
          <span class="text-on-surface">Create New Agent</span>
        </div>
        <h1 class="text-4xl font-extrabold font-headline tracking-tight text-on-surface">Create New Agent</h1>
        <p class="text-on-surface-variant mt-2">Configure and deploy a new AI agent for your workspace.</p>
      </section>

      <%!-- Template Selector --%>
      <section>
        <h2 class="text-sm font-bold uppercase tracking-wider text-on-surface-variant mb-4">Start from a Template</h2>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <button
            :for={{key, tmpl} <- templates()}
            phx-click="select_template"
            phx-value-template={key}
            class={[
              "bg-surface-container p-5 rounded-xl text-left transition-all hover:shadow-md group border-2",
              if(@selected_template == key, do: "border-primary shadow-md", else: "border-transparent hover:border-primary/20")
            ]}
          >
            <span class="material-symbols-outlined text-primary text-2xl mb-3 block group-hover:scale-110 transition-transform">
              {template_icon(key)}
            </span>
            <p class="text-sm font-bold text-on-surface">{if(tmpl.name != "", do: tmpl.name, else: "Custom")}</p>
            <p class="text-xs text-on-surface-variant mt-1 line-clamp-2">
              {if key == "custom", do: "Start from scratch with your own configuration", else: tmpl.description}
            </p>
          </button>
        </div>
      </section>

      <%!-- Form --%>
      <form id="agent-form" phx-submit="create_agent" class="space-y-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <%!-- Left column: Basic info --%>
          <div class="lg:col-span-2 space-y-6">
            <div class="bg-surface-container rounded-2xl p-6 space-y-6">
              <h3 class="font-bold text-lg text-on-surface">Agent Details</h3>

              <div>
                <label class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2 block">Agent Name <span class="text-error">*</span></label>
                <input
                  type="text"
                  name="agent[name]"
                  value={@form_data["name"]}
                  placeholder="e.g., Research Assistant"
                  required
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface focus:ring-2 focus:ring-primary placeholder:text-on-surface-variant/50"
                  phx-change="update_field"
                  phx-value-field="name"
                />
              </div>

              <div>
                <label class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2 block">Description</label>
                <input
                  type="text"
                  name="agent[description]"
                  value={@form_data["description"]}
                  placeholder="Brief description of what this agent does"
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface focus:ring-2 focus:ring-primary placeholder:text-on-surface-variant/50"
                />
              </div>

              <div>
                <label class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2 block">System Prompt <span class="text-error">*</span></label>
                <textarea
                  name="agent[system_prompt]"
                  rows="5"
                  required
                  placeholder="Instructions for how the agent should behave..."
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface focus:ring-2 focus:ring-primary placeholder:text-on-surface-variant/50 resize-none"
                >{@form_data["system_prompt"]}</textarea>
              </div>
            </div>
          </div>

          <%!-- Right column: Configuration --%>
          <div class="space-y-6">
            <div class="bg-surface-container rounded-2xl p-6 space-y-6">
              <h3 class="font-bold text-lg text-on-surface">Configuration</h3>

              <div>
                <label class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2 block">Provider</label>
                <select
                  name="agent[provider]"
                  phx-change="change_provider"
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface focus:ring-2 focus:ring-primary"
                >
                  <option value="anthropic" selected={@form_data["provider"] == "anthropic"}>Anthropic</option>
                  <option value="openai" selected={@form_data["provider"] == "openai"}>OpenAI</option>
                </select>
              </div>

              <div>
                <label class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2 block">Model</label>
                <select
                  name="agent[model]"
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface focus:ring-2 focus:ring-primary"
                >
                  <option :for={{label, value} <- @models} value={value} selected={@form_data["model"] == value}>
                    {label}
                  </option>
                </select>
              </div>

              <div>
                <div class="flex justify-between items-center mb-2">
                  <label class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant">Temperature</label>
                  <span class="text-sm font-mono text-primary font-bold">{@form_data["temperature"]}</span>
                </div>
                <input
                  type="range"
                  name="agent[temperature]"
                  min="0"
                  max="1"
                  step="0.1"
                  value={@form_data["temperature"]}
                  phx-change="update_temperature"
                  class="w-full h-1.5 bg-surface-container-highest rounded-full appearance-none cursor-pointer accent-primary"
                />
                <div class="flex justify-between text-[10px] text-on-surface-variant mt-1">
                  <span>Precise</span>
                  <span>Creative</span>
                </div>
              </div>

              <div>
                <label class="text-[10px] font-bold tracking-wider uppercase text-on-surface-variant mb-2 block">Max Tokens</label>
                <div class="grid grid-cols-4 gap-2 bg-surface-container-high p-1 rounded-lg text-xs font-mono font-medium">
                  <button
                    :for={t <- [1024, 2048, 4096, 8192]}
                    type="button"
                    phx-click="set_max_tokens"
                    phx-value-tokens={t}
                    class={[
                      "py-2 rounded-md transition-colors",
                      if(@form_data["max_tokens"] == to_string(t),
                        do: "bg-primary text-on-primary",
                        else: "text-on-surface-variant hover:text-on-surface"
                      )
                    ]}
                  >
                    {t}
                  </button>
                </div>
                <input type="hidden" name="agent[max_tokens]" value={@form_data["max_tokens"]} />
              </div>
            </div>

            <%!-- Error display --%>
            <div :if={@error} class="bg-error/10 text-error text-sm font-medium p-4 rounded-xl">
              {@error}
            </div>
          </div>
        </div>

        <%!-- Submit --%>
        <div class="flex items-center justify-between pt-4">
          <.link navigate="/agents" class="text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors">
            Cancel
          </.link>
          <button type="submit" class="primary-gradient px-8 py-3 rounded-lg text-sm font-bold transition-transform hover:scale-[1.02] active:scale-95 flex items-center gap-2">
            <span class="material-symbols-outlined text-lg">rocket_launch</span>
            Deploy Agent
          </button>
        </div>
      </form>
    </div>
    """
  end

  # ── Events ──

  def handle_event("select_template", %{"template" => template_key}, socket) do
    case Map.get(@templates, template_key) do
      nil ->
        {:noreply, socket}

      tmpl ->
        form_data =
          socket.assigns.form_data
          |> Map.put("name", tmpl.name)
          |> Map.put("description", tmpl.description)
          |> Map.put("system_prompt", tmpl.system_prompt)
          |> Map.put("temperature", to_string(tmpl.temperature))
          |> Map.put("max_tokens", to_string(tmpl.max_tokens))

        {:noreply, assign(socket, selected_template: template_key, form_data: form_data)}
    end
  end

  def handle_event("change_provider", %{"agent" => %{"provider" => provider}}, socket) do
    models = @models_by_provider[provider] || @models_by_provider["anthropic"]
    {_, default_model} = List.first(models)

    form_data =
      socket.assigns.form_data
      |> Map.put("provider", provider)
      |> Map.put("model", default_model)

    {:noreply, assign(socket, form_data: form_data, models: models)}
  end

  def handle_event("update_field", %{"agent" => params}, socket) do
    form_data = Map.merge(socket.assigns.form_data, params)
    {:noreply, assign(socket, form_data: form_data)}
  end

  def handle_event("update_temperature", %{"agent" => %{"temperature" => val}}, socket) do
    form_data = Map.put(socket.assigns.form_data, "temperature", val)
    {:noreply, assign(socket, form_data: form_data)}
  end

  def handle_event("set_max_tokens", %{"tokens" => tokens}, socket) do
    form_data = Map.put(socket.assigns.form_data, "max_tokens", tokens)
    {:noreply, assign(socket, form_data: form_data)}
  end

  def handle_event("create_agent", %{"agent" => params}, socket) do
    org = socket.assigns.org

    if is_nil(org) do
      {:noreply, assign(socket, error: "No organisation found. Please complete onboarding first.")}
    else
      {temperature, _} = Float.parse(params["temperature"] || "0.7")
      {max_tokens, _} = Integer.parse(params["max_tokens"] || "4096")

      create_params = %{
        name: params["name"],
        description: params["description"],
        system_prompt: params["system_prompt"],
        model: params["model"],
        provider: String.to_existing_atom(params["provider"]),
        temperature: temperature,
        max_tokens: max_tokens,
        organisation_id: org.id
      }

      case FounderPad.AI.Agent
           |> Ash.Changeset.for_create(:create, create_params)
           |> Ash.create() do
        {:ok, agent} ->
          {:noreply,
           socket
           |> put_flash(:info, "Agent \"#{agent.name}\" deployed successfully!")
           |> push_navigate(to: "/agents/#{agent.id}")}

        {:error, changeset} ->
          error_msg =
            case changeset do
              %Ash.Error.Invalid{} = err ->
                err.errors
                |> Enum.map(fn e -> Exception.message(e) end)
                |> Enum.join(", ")

              _ ->
                "Failed to create agent. Please check all required fields."
            end

          {:noreply, assign(socket, error: error_msg)}
      end
    end
  end

  # ── Helpers ──

  defp load_user_org(nil), do: nil

  defp load_user_org(user) do
    case FounderPad.Accounts.Membership
         |> Ash.Query.filter(user_id: user.id)
         |> Ash.Query.sort(inserted_at: :asc)
         |> Ash.Query.limit(1)
         |> Ash.Query.load(:organisation)
         |> Ash.read() do
      {:ok, [membership | _]} -> membership.organisation
      _ -> nil
    end
  end

  defp templates, do: @templates

  defp template_icon("research"), do: "science"
  defp template_icon("code_review"), do: "code"
  defp template_icon("content"), do: "edit_note"
  defp template_icon("custom"), do: "tune"
  defp template_icon(_), do: "smart_toy"
end
