defmodule FounderPadWeb.AgentDetailLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers
  use Oban.Testing, repo: FounderPad.Repo

  import FounderPad.Factory

  describe "mount" do
    test "loads agent and renders its name", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org, %{name: "Research Bot", description: "Analyzes data"})

      {:ok, _view, html} = live(conn, "/agents/#{agent.id}")

      assert html =~ "Research Bot"
      assert html =~ "Analyzes data"
    end

    test "redirects to /agents for non-existent agent", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)

      assert {:error, {:live_redirect, %{to: "/agents"}}} =
               live(conn, "/agents/#{Ash.UUID.generate()}")
    end

    test "creates a conversation on first visit", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org)

      {:ok, _view, _html} = live(conn, "/agents/#{agent.id}")

      require Ash.Query

      {:ok, convos} =
        FounderPad.AI.Conversation
        |> Ash.Query.filter(agent_id: agent.id)
        |> Ash.read()

      assert length(convos) == 1
    end

    test "reuses existing active conversation", %{conn: conn} do
      {conn, user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org)

      {:ok, existing_convo} =
        FounderPad.AI.Conversation
        |> Ash.Changeset.for_create(:create, %{
          title: "Existing chat",
          agent_id: agent.id,
          organisation_id: org.id,
          user_id: user.id
        })
        |> Ash.create()

      {:ok, _view, _html} = live(conn, "/agents/#{agent.id}")

      require Ash.Query

      {:ok, convos} =
        FounderPad.AI.Conversation
        |> Ash.Query.filter(agent_id: agent.id, status: :active)
        |> Ash.read()

      assert length(convos) == 1
      assert hd(convos).id == existing_convo.id
    end
  end

  describe "send_message" do
    test "adds user message to the UI optimistically", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org)

      {:ok, view, _html} = live(conn, "/agents/#{agent.id}")

      # Switch to chat tab first (form is only rendered when chat tab is active)
      view |> element("button[phx-value-tab=chat]") |> render_click()

      html =
        view
        |> form("form[phx-submit=send_message]", %{message: "Hello agent"})
        |> render_submit()

      assert html =~ "Hello agent"
    end

    test "enqueues an AgentRunner job", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org)

      {:ok, view, _html} = live(conn, "/agents/#{agent.id}")

      # Switch to chat tab first
      view |> element("button[phx-value-tab=chat]") |> render_click()

      view
      |> form("form[phx-submit=send_message]", %{message: "Test message"})
      |> render_submit()

      assert_enqueued(
        worker: FounderPad.AI.Workers.AgentRunner,
        args: %{message_content: "Test message"}
      )
    end

    test "does not send empty messages", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org)

      {:ok, view, _html} = live(conn, "/agents/#{agent.id}")

      # Switch to chat tab first
      view |> element("button[phx-value-tab=chat]") |> render_click()

      view
      |> form("form[phx-submit=send_message]", %{message: ""})
      |> render_submit()

      refute_enqueued(worker: FounderPad.AI.Workers.AgentRunner)
    end
  end

  describe "PubSub message handling" do
    test "message_complete adds assistant message to UI", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org)

      {:ok, view, _html} = live(conn, "/agents/#{agent.id}")

      # Switch to chat tab so messages are rendered
      view |> element("button[phx-value-tab=chat]") |> render_click()

      # Get conversation_id from the LiveView process state
      state = :sys.get_state(view.pid)
      conversation_id = state.socket.assigns.conversation.id

      # Simulate PubSub broadcast from AgentRunner
      Phoenix.PubSub.broadcast(
        FounderPad.PubSub,
        "conversation:#{conversation_id}",
        {:message_complete, "Here is my response"}
      )

      html = render(view)
      assert html =~ "Here is my response"
    end

    test "error broadcast shows flash message", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      agent = create_agent!(org)

      {:ok, view, _html} = live(conn, "/agents/#{agent.id}")

      state = :sys.get_state(view.pid)
      conversation_id = state.socket.assigns.conversation.id

      Phoenix.PubSub.broadcast(
        FounderPad.PubSub,
        "conversation:#{conversation_id}",
        {:error, "Provider timeout"}
      )

      html = render(view)
      assert html =~ "Agent error"
    end
  end
end
