defmodule FounderPadWeb.CookieConsentController do
  use FounderPadWeb, :controller

  def create(conn, params) do
    consent_params = %{
      consent_id: params["consent_id"] || Ecto.UUID.generate(),
      analytics: params["analytics"] == "true" || params["analytics"] == true,
      marketing: params["marketing"] == "true" || params["marketing"] == true,
      functional: true,
      ip_address: to_string(:inet.ntoa(conn.remote_ip)),
      user_agent: List.first(get_req_header(conn, "user-agent")) || ""
    }

    case FounderPad.Privacy.CookieConsent
         |> Ash.Changeset.for_create(:create, consent_params)
         |> Ash.create() do
      {:ok, consent} ->
        conn
        |> put_resp_cookie("cookie_consent", consent.consent_id, max_age: 365 * 24 * 3600)
        |> json(%{status: "ok", consent_id: consent.consent_id})

      {:error, _} ->
        conn |> put_status(422) |> json(%{status: "error"})
    end
  end
end
