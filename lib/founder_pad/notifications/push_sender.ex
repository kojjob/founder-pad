defmodule FounderPad.Notifications.PushSender do
  @moduledoc "Sends push notifications via FCM and Web Push APIs."

  @doc "Build FCM HTTP v1 API payload."
  def build_fcm_payload(notification, device_token) do
    %{
      "message" => %{
        "token" => device_token,
        "notification" => %{
          "title" => notification[:title],
          "body" => notification[:body]
        },
        "data" => %{
          "action_url" => notification[:action_url] || "/"
        }
      }
    }
  end

  @doc "Build Web Push notification payload."
  def build_web_push_payload(notification) do
    Jason.encode!(%{
      "title" => notification[:title],
      "body" => notification[:body],
      "icon" => "/images/logo-icon.png",
      "badge" => "/images/badge.png",
      "data" => %{
        "url" => notification[:action_url] || "/"
      }
    })
  end

  @doc "Send push to an FCM device. Returns :ok or {:error, reason}."
  def send_fcm(notification, device_token) do
    payload = build_fcm_payload(notification, device_token)

    case get_fcm_config() do
      nil ->
        {:error, "FCM not configured"}

      config ->
        url = "https://fcm.googleapis.com/v1/projects/#{config.project_id}/messages:send"

        case Req.post(url,
               json: payload,
               headers: [{"authorization", "Bearer #{get_fcm_access_token(config)}"}]
             ) do
          {:ok, %{status: 200}} ->
            :ok

          {:ok, %{status: status, body: body}} ->
            {:error, "FCM error #{status}: #{inspect(body)}"}

          {:error, reason} ->
            {:error, inspect(reason)}
        end
    end
  end

  @doc "Send web push notification. Returns :ok or {:error, reason}."
  def send_web_push(notification, subscription_json) do
    case get_vapid_config() do
      nil ->
        {:error, "Web Push not configured"}

      vapid ->
        payload = build_web_push_payload(notification)
        subscription = Jason.decode!(subscription_json)

        if Code.ensure_loaded?(WebPush) do
          case WebPush.send_notification(
                 subscription,
                 payload,
                 vapid_public_key: vapid.public_key,
                 vapid_private_key: vapid.private_key,
                 vapid_subject: vapid.subject
               ) do
            {:ok, _} -> :ok
            {:error, reason} -> {:error, inspect(reason)}
          end
        else
          {:error, "WebPush library not available"}
        end
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp get_fcm_config do
    push_config = Application.get_env(:founder_pad, :push, [])

    case push_config[:fcm_service_account] do
      nil ->
        nil

      json_str ->
        case Jason.decode(json_str) do
          {:ok, data} ->
            %{
              project_id: data["project_id"],
              client_email: data["client_email"],
              private_key: data["private_key"]
            }

          _ ->
            nil
        end
    end
  end

  defp get_fcm_access_token(_config) do
    # In production, this would use Google OAuth2 JWT flow.
    # For now, return empty -- FCM will fail gracefully if not configured.
    ""
  end

  defp get_vapid_config do
    push_config = Application.get_env(:founder_pad, :push, [])

    case {push_config[:vapid_public_key], push_config[:vapid_private_key]} do
      {nil, _} ->
        nil

      {_, nil} ->
        nil

      {pub, priv} ->
        %{
          public_key: pub,
          private_key: priv,
          subject: push_config[:vapid_subject] || "mailto:support@founderpad.io"
        }
    end
  end
end
