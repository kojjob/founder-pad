defmodule FounderPadWeb.Plugs.ApiKeyAuthTest do
  use FounderPadWeb.ConnCase, async: true
  import FounderPad.Factory

  alias FounderPadWeb.Plugs.ApiKeyAuth

  describe "call/2" do
    test "authenticates with valid API key" do
      user = create_user!()
      org = create_organisation!()
      create_membership!(user, org, :owner)
      key = create_api_key!(org, user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{key.__raw_key__}")
        |> ApiKeyAuth.call([])

      assert conn.assigns[:api_key]
      assert conn.assigns[:current_organisation].id == org.id
    end

    test "does nothing with no auth header" do
      conn = build_conn() |> ApiKeyAuth.call([])
      refute conn.assigns[:api_key]
    end

    test "does nothing with invalid key" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid_key")
        |> ApiKeyAuth.call([])

      refute conn.assigns[:api_key]
    end

    test "does not authenticate revoked key" do
      user = create_user!()
      org = create_organisation!()
      create_membership!(user, org, :owner)
      key = create_api_key!(org, user)
      raw = key.__raw_key__

      key |> Ash.Changeset.for_update(:revoke, %{}) |> Ash.update!()

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{raw}")
        |> ApiKeyAuth.call([])

      refute conn.assigns[:api_key]
    end
  end
end
