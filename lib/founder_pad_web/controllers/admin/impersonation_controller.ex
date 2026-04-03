defmodule FounderPadWeb.Admin.ImpersonationController do
  @moduledoc """
  Controller for starting and stopping admin user impersonation.
  Uses session-based impersonation so LiveView hooks can detect the impersonated user.
  """
  use FounderPadWeb, :controller

  def start(conn, %{"id" => user_id}) do
    case load_admin_from_session(conn) do
      {:ok, admin} when admin.is_admin ->
        conn
        |> put_session(:impersonated_user_id, user_id)
        |> put_flash(:info, "Now impersonating user")
        |> redirect(to: "/dashboard")

      _ ->
        conn
        |> put_flash(:error, "Unauthorized")
        |> redirect(to: "/dashboard")
    end
  end

  def stop(conn, _params) do
    conn
    |> delete_session(:impersonated_user_id)
    |> put_flash(:info, "Impersonation ended")
    |> redirect(to: "/admin/users")
  end

  defp load_admin_from_session(conn) do
    case get_session(conn, :user_token) do
      nil -> :error
      token -> AshAuthentication.subject_to_user(token, FounderPad.Accounts.User)
    end
  end
end
