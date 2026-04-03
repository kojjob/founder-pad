defmodule FounderPadWeb.PrivacyLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Privacy Policy"), layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <nav class="sticky top-0 z-50 bg-white/80 backdrop-blur-md border-b border-neutral-200/60">
        <div class="max-w-4xl mx-auto px-6 h-16 flex items-center justify-between">
          <a href="/" class="font-heading font-bold text-xl text-on-surface">FounderPad</a>
          <a href="/auth/login" class="px-4 py-2 bg-primary text-white rounded-lg">Sign In</a>
        </div>
      </nav>
      <main class="max-w-4xl mx-auto px-6 py-16 prose">
        <h1>Privacy Policy</h1>
        <p><em>Last updated: April 2026</em></p>

        <h2>Data We Collect</h2>
        <p>We collect information you provide directly: email address, name, and usage data to improve our service.</p>

        <h2>How We Use Your Data</h2>
        <p>Your data is used to provide and improve FounderPad services, send transactional emails, and (with your consent) marketing communications.</p>

        <h2>Your Rights (GDPR)</h2>
        <ul>
          <li><strong>Access</strong> -- Request a copy of your data via Settings -> Export Data</li>
          <li><strong>Deletion</strong> -- Request account deletion via Settings -> Delete Account</li>
          <li><strong>Portability</strong> -- Download your data in JSON format</li>
          <li><strong>Opt-out</strong> -- Unsubscribe from marketing emails at any time</li>
        </ul>

        <h2>Cookie Policy</h2>
        <p>We use essential cookies for authentication and optional analytics cookies (with your consent).</p>

        <h2>Contact</h2>
        <p>For privacy inquiries: <a href="/help/contact">Contact Support</a></p>
      </main>
    </div>
    """
  end
end
