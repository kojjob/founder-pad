defmodule LinkHubWeb.ShareLinkControllerTest do
  use LinkHubWeb.ConnCase, async: true

  alias LinkHub.Factory
  require Ash.Query

  setup do
    workspace = Factory.create_workspace!()
    user = Factory.create_user!()
    Factory.create_membership!(user, workspace)
    stored_file = Factory.create_stored_file!(workspace, user)
    %{workspace: workspace, user: user, stored_file: stored_file}
  end

  defp create_share_link!(ctx, attrs \\ %{}) do
    defaults = %{
      stored_file_id: ctx.stored_file.id,
      created_by_id: ctx.user.id
    }

    LinkHub.Media.ShareLink
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, Map.new(attrs)))
    |> Ash.create!()
  end

  describe "GET /s/:token (show)" do
    test "returns file metadata and download URL for valid token", %{conn: conn} = ctx do
      link = create_share_link!(ctx)

      conn = get(conn, "/s/#{link.token}")
      body = json_response(conn, 200)

      assert body["download_url"] =~ "presigned=get"
      assert body["filename"] == ctx.stored_file.filename
      assert body["content_type"] == ctx.stored_file.content_type
    end

    test "returns password_required for password-protected links", %{conn: conn} = ctx do
      link =
        create_share_link!(ctx, %{
          password_hash: Bcrypt.hash_pwd_salt("secret123")
        })

      conn = get(conn, "/s/#{link.token}")
      body = json_response(conn, 200)

      assert body["password_required"] == true
      assert body["filename"] == ctx.stored_file.filename
      refute Map.has_key?(body, "download_url")
    end

    test "returns 404 for invalid token", %{conn: conn} do
      conn = get(conn, "/s/nonexistent-token")

      assert json_response(conn, 404)["error"] == "Link not found"
    end

    test "returns 410 for expired links", %{conn: conn} = ctx do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)

      link = create_share_link!(ctx, %{expires_at: past})

      conn = get(conn, "/s/#{link.token}")

      assert json_response(conn, 410)["error"] == "Link has expired"
    end

    test "returns 410 when download limit is reached", %{conn: conn} = ctx do
      link = create_share_link!(ctx, %{max_downloads: 1})

      # Record a download to exhaust the limit
      link
      |> Ash.Changeset.for_update(:record_download)
      |> Ash.update!()

      conn = get(conn, "/s/#{link.token}")

      assert json_response(conn, 410)["error"] == "Download limit reached"
    end
  end

  describe "POST /s/:token/unlock" do
    test "returns download URL with correct password", %{conn: conn} = ctx do
      password = "secret123"

      link =
        create_share_link!(ctx, %{
          password_hash: Bcrypt.hash_pwd_salt(password)
        })

      conn = post(conn, "/s/#{link.token}/unlock", %{"password" => password})
      body = json_response(conn, 200)

      assert body["download_url"] =~ "presigned=get"
      assert body["filename"] == ctx.stored_file.filename
    end

    test "returns 401 with wrong password", %{conn: conn} = ctx do
      link =
        create_share_link!(ctx, %{
          password_hash: Bcrypt.hash_pwd_salt("correct-password")
        })

      conn = post(conn, "/s/#{link.token}/unlock", %{"password" => "wrong-password"})

      assert json_response(conn, 401)["error"] == "Invalid password"
    end

    test "returns 404 for invalid token", %{conn: conn} do
      conn = post(conn, "/s/nonexistent-token/unlock", %{"password" => "anything"})

      assert json_response(conn, 404)["error"] == "Link not found"
    end
  end
end
