defmodule FounderPadWeb.TermsLive do
  use FounderPadWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Terms of Service"), layout: false}
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
        <h1>Terms of Service</h1>
        <p><em>Last updated: April 2026</em></p>

        <h2>1. Acceptance of Terms</h2>
        <p>
          By accessing or using FounderPad, you agree to be bound by these Terms of Service and our Privacy Policy.
        </p>

        <h2>2. Description of Service</h2>
        <p>
          FounderPad provides an AI agent management platform that allows users to create, configure, and deploy AI-powered agents.
        </p>

        <h2>3. User Accounts</h2>
        <p>
          You are responsible for maintaining the security of your account credentials. You must provide accurate information when creating an account.
        </p>

        <h2>4. Acceptable Use</h2>
        <p>You agree not to misuse the service, including but not limited to:</p>
        <ul>
          <li>Violating any applicable laws or regulations</li>
          <li>Attempting to gain unauthorized access to systems</li>
          <li>Distributing malware or harmful content</li>
          <li>Exceeding rate limits or abusing the API</li>
        </ul>

        <h2>5. Intellectual Property</h2>
        <p>
          You retain ownership of content you create using FounderPad. We retain ownership of the platform and its underlying technology.
        </p>

        <h2>6. Payment Terms</h2>
        <p>
          Paid plans are billed in advance on a monthly or annual basis. Refunds are handled on a case-by-case basis.
        </p>

        <h2>7. Termination</h2>
        <p>
          Either party may terminate the agreement at any time. Upon termination, you may export your data within 30 days.
        </p>

        <h2>8. Limitation of Liability</h2>
        <p>
          FounderPad is provided "as is" without warranties. We are not liable for indirect, incidental, or consequential damages.
        </p>

        <h2>9. Changes to Terms</h2>
        <p>
          We may update these terms from time to time. Continued use of the service constitutes acceptance of the updated terms.
        </p>

        <h2>10. Contact</h2>
        <p>For questions about these terms: <a href="/help/contact">Contact Support</a></p>
      </main>
    </div>
    """
  end
end
