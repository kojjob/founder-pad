defmodule FounderPadWeb.Help.HelpContactLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Contact Support — FounderPad",
       form_data: %{name: "", email: "", subject: "", message: ""},
       form_errors: %{},
       submitted: false
     ), layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary">
      <.help_nav active="help" />

      <div class="pt-20 max-w-2xl mx-auto px-6 py-16">
        <a
          href="/help"
          class="text-sm text-on-surface-variant hover:text-primary transition-colors flex items-center gap-1 mb-6"
        >
          <span class="material-symbols-outlined text-sm">arrow_back</span> Back to Help Center
        </a>

        <h1 class="font-heading text-3xl font-extrabold tracking-tight text-on-surface mb-2">
          Contact Support
        </h1>
        <p class="text-on-surface-variant mb-8">
          Can't find what you're looking for? Send us a message and we'll get back to you.
        </p>

        <div :if={@submitted} class="bg-green-50 border border-green-200 rounded-xl p-6 text-center">
          <span class="material-symbols-outlined text-green-600 text-4xl mb-2 block">
            check_circle
          </span>
          <h2 class="text-lg font-bold text-green-800 mb-1">Message sent!</h2>
          <p class="text-sm text-green-700">
            We've received your message and will get back to you as soon as possible.
          </p>
          <a
            href="/help"
            class="inline-block mt-4 text-sm text-primary hover:underline"
          >
            Return to Help Center
          </a>
        </div>

        <form :if={!@submitted} phx-submit="submit" phx-change="validate" class="space-y-6">
          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Name</label>
            <input
              type="text"
              name="contact[name]"
              value={@form_data.name}
              phx-debounce="300"
              placeholder="Your name"
              class={"w-full rounded-lg border px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors #{if @form_errors[:name], do: "border-red-400", else: "border-outline-variant/30"}"}
            />
            <p :if={@form_errors[:name]} class="text-red-500 text-xs mt-1">{@form_errors[:name]}</p>
          </div>

          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Email</label>
            <input
              type="email"
              name="contact[email]"
              value={@form_data.email}
              phx-debounce="300"
              placeholder="you@example.com"
              class={"w-full rounded-lg border px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors #{if @form_errors[:email], do: "border-red-400", else: "border-outline-variant/30"}"}
            />
            <p :if={@form_errors[:email]} class="text-red-500 text-xs mt-1">{@form_errors[:email]}</p>
          </div>

          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Subject</label>
            <input
              type="text"
              name="contact[subject]"
              value={@form_data.subject}
              phx-debounce="300"
              placeholder="What can we help with?"
              class={"w-full rounded-lg border px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors #{if @form_errors[:subject], do: "border-red-400", else: "border-outline-variant/30"}"}
            />
            <p :if={@form_errors[:subject]} class="text-red-500 text-xs mt-1">
              {@form_errors[:subject]}
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-on-surface mb-2">Message</label>
            <textarea
              name="contact[message]"
              rows="5"
              phx-debounce="300"
              placeholder="Describe your issue or question..."
              class={"w-full rounded-lg border px-4 py-3 text-on-surface bg-surface-container-highest focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors resize-none #{if @form_errors[:message], do: "border-red-400", else: "border-outline-variant/30"}"}
            >{@form_data.message}</textarea>
            <p :if={@form_errors[:message]} class="text-red-500 text-xs mt-1">
              {@form_errors[:message]}
            </p>
          </div>

          <button
            type="submit"
            class="w-full primary-gradient px-6 py-3 rounded-lg text-sm font-semibold transition-transform hover:scale-[1.01] active:scale-95"
          >
            Send Message
          </button>
        </form>
      </div>

      <.public_footer />
    </div>
    """
  end

  def handle_event("validate", %{"contact" => params}, socket) do
    form_data = %{
      name: Map.get(params, "name", ""),
      email: Map.get(params, "email", ""),
      subject: Map.get(params, "subject", ""),
      message: Map.get(params, "message", "")
    }

    {:noreply, assign(socket, form_data: form_data)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("submit", %{"contact" => params}, socket) do
    form_data = %{
      name: Map.get(params, "name", ""),
      email: Map.get(params, "email", ""),
      subject: Map.get(params, "subject", ""),
      message: Map.get(params, "message", "")
    }

    errors = validate_form(form_data)

    if map_size(errors) > 0 do
      {:noreply,
       socket
       |> assign(form_data: form_data, form_errors: errors)
       |> put_flash(:error, "Please fix the errors below.")}
    else
      case FounderPad.HelpCenter.ContactRequest
           |> Ash.Changeset.for_create(:create, %{
             name: form_data.name,
             email: form_data.email,
             subject: form_data.subject,
             message: form_data.message
           })
           |> Ash.create() do
        {:ok, _request} ->
          {:noreply, assign(socket, submitted: true)}

        {:error, _error} ->
          {:noreply,
           socket
           |> assign(form_data: form_data)
           |> put_flash(:error, "Something went wrong. Please try again.")}
      end
    end
  end

  defp validate_form(data) do
    errors = %{}

    errors =
      if String.trim(data.name) == "",
        do: Map.put(errors, :name, "Name is required"),
        else: errors

    errors =
      if String.trim(data.email) == "",
        do: Map.put(errors, :email, "Email is required"),
        else: errors

    errors =
      if String.trim(data.subject) == "",
        do: Map.put(errors, :subject, "Subject is required"),
        else: errors

    errors =
      if String.trim(data.message) == "",
        do: Map.put(errors, :message, "Message is required"),
        else: errors

    errors
  end

  defp help_nav(assigns) do
    ~H"""
    <nav class="fixed top-0 inset-x-0 z-50 bg-background/60 backdrop-blur-md">
      <div class="max-w-7xl mx-auto flex items-center justify-between px-6 py-4">
        <a href="/" class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
            <span class="material-symbols-outlined text-on-primary text-lg">architecture</span>
          </div>
          <span class="text-xl font-extrabold font-headline tracking-tight text-on-surface">
            FounderPad
          </span>
        </a>

        <div class="hidden md:flex items-center gap-8 text-sm font-medium text-on-surface-variant">
          <a href="/blog" class="hover:text-on-surface transition-colors">Blog</a>
          <a href="/docs" class="hover:text-on-surface transition-colors">Docs</a>
          <a
            href="/help"
            class={"hover:text-on-surface transition-colors " <> if(@active == "help", do: "text-primary", else: "")}
          >
            Help
          </a>
          <a href="/auth/login" class="hover:text-on-surface transition-colors">Sign In</a>
        </div>

        <div class="flex items-center gap-3">
          <a
            href="/auth/register"
            class="hidden sm:inline-flex items-center px-5 py-2 rounded-lg text-sm font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95"
          >
            Get Started
          </a>
          <button
            id="theme-toggle-help-contact"
            phx-hook="ThemeToggle"
            class="p-2 text-on-surface-variant hover:text-on-surface transition-colors cursor-pointer rounded-lg hover:bg-surface-container-high/50"
          >
            <span class="material-symbols-outlined text-xl">dark_mode</span>
          </button>
        </div>
      </div>
    </nav>
    """
  end
end
