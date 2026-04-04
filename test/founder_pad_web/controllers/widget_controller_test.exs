defmodule FounderPadWeb.WidgetControllerTest do
  use FounderPadWeb.ConnCase, async: true

  alias FounderPad.Factory

  describe "widget endpoints" do
    test "script endpoint returns JavaScript", %{conn: conn} do
      org = Factory.create_organisation!()
      agent = Factory.create_agent!(org)

      conn = get(conn, "/widget/embed/#{agent.id}")

      assert response_content_type(conn, :js) =~ "javascript"
      assert response(conn, 200) =~ "fp-widget"
      assert response(conn, 200) =~ agent.id
    end

    test "chat endpoint returns HTML", %{conn: conn} do
      org = Factory.create_organisation!()
      agent = Factory.create_agent!(org)

      conn = get(conn, "/widget/chat/#{agent.id}")

      assert response_content_type(conn, :html) =~ "html"
      assert response(conn, 200) =~ "FounderPad Assistant"
      assert response(conn, 200) =~ "sendMsg"
    end
  end
end
