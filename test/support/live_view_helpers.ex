defmodule FounderPad.LiveViewHelpers do
  @moduledoc """
  Shared helpers for LiveView integration tests.
  Import this module in test cases that need LiveView interaction helpers.

  Usage:
      use FounderPad.LiveViewHelpers
  """

  defmacro __using__(_opts) do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import FounderPad.LiveViewHelpers
    end
  end

  alias FounderPad.Factory

  @doc "Create a user, org, and membership, returning {conn, user, org}."
  def setup_authenticated_user(conn) do
    user = Factory.create_user!()
    org = Factory.create_organisation!()
    Factory.create_membership!(user, org, :owner)

    token = AshAuthentication.user_to_subject(user)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, user, org}
  end
end
