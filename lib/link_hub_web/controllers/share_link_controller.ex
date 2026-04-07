defmodule LinkHubWeb.ShareLinkController do
  @moduledoc "Public controller for accessing shared file download links."
  use LinkHubWeb, :controller

  require Ash.Query

  def show(conn, %{"token" => token}) do
    case get_share_link(token) do
      {:ok, link} ->
        cond do
          expired?(link) ->
            conn |> put_status(:gone) |> json(%{error: "Link has expired"})

          link.password_hash ->
            json(conn, %{
              filename: link.stored_file.filename,
              content_type: link.stored_file.content_type,
              size_bytes: link.stored_file.size_bytes,
              password_required: true
            })

          true ->
            serve_download(conn, link)
        end

      {:error, _} ->
        conn |> put_status(:not_found) |> json(%{error: "Link not found"})
    end
  end

  def unlock(conn, %{"token" => token, "password" => password}) do
    case get_share_link(token) do
      {:ok, link} ->
        if Bcrypt.verify_pass(password, link.password_hash || "") do
          serve_download(conn, link)
        else
          conn |> put_status(:unauthorized) |> json(%{error: "Invalid password"})
        end

      {:error, _} ->
        conn |> put_status(:not_found) |> json(%{error: "Link not found"})
    end
  end

  defp get_share_link(token) do
    LinkHub.Media.ShareLink
    |> Ash.Query.for_read(:get_by_token, %{token: token})
    |> Ash.read_one()
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, link} -> {:ok, link}
      error -> error
    end
  end

  defp serve_download(conn, link) do
    if link.max_downloads && link.download_count >= link.max_downloads do
      conn |> put_status(:gone) |> json(%{error: "Download limit reached"})
    else
      link
      |> Ash.Changeset.for_update(:record_download)
      |> Ash.update!()

      case LinkHub.Media.Storage.presigned_download_url(
             link.stored_file.storage_key,
             filename: link.stored_file.filename
           ) do
        {:ok, url} ->
          json(conn, %{
            download_url: url,
            filename: link.stored_file.filename,
            content_type: link.stored_file.content_type
          })

        {:error, _} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to generate download URL"})
      end
    end
  end

  defp expired?(%{expires_at: nil}), do: false

  defp expired?(%{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end
end
