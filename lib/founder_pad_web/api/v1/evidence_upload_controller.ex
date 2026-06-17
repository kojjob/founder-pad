defmodule FounderPadWeb.Api.V1.EvidenceUploadController do
  @moduledoc """
  Issues a short-lived signed URL for uploading evidence (selfie/document) against a
  verification. The client uploads directly to object storage; only metadata is stored.
  """
  use FounderPadWeb, :controller

  alias FounderPad.Compliance
  alias FounderPad.Compliance.{EvidenceItem, IndividualVerification}
  alias FounderPadWeb.Api.{Errors, RequestId}

  @type_atoms %{
    "selfie" => :selfie,
    "document_front" => :document_front,
    "document_back" => :document_back,
    "proof_of_address" => :proof_of_address,
    "business_document" => :business_document
  }
  @valid_types Map.keys(@type_atoms)

  plug :require_scope, "write"

  def create(conn, %{"id" => verification_id} = params) do
    org = conn.assigns.current_organisation
    type = Map.get(params, "type")

    with {:ok, ivf} <- fetch_verification(verification_id, org),
         {:ok, type_atom} <- validate_type(type),
         {:ok, item} <- request_upload(org, ivf, type_atom, params) do
      audit(conn, org, ivf, item)

      conn
      |> put_status(201)
      |> json(%{
        evidence_id: item.id,
        upload_url: item.__upload_url__,
        expires_at: item.expires_at
      })
    else
      {:error, :not_found} ->
        Errors.send(conn, 404, "verification_not_found", "No verification with that id.")

      {:error, :invalid_type} ->
        Errors.send(
          conn,
          422,
          "validation_failed",
          "type must be one of: #{Enum.join(@valid_types, ", ")}."
        )

      {:error, _other} ->
        Errors.send(conn, 422, "validation_failed", "Could not create the evidence upload.")
    end
  end

  defp fetch_verification(id, org) do
    case Ash.get(IndividualVerification, id, authorize?: false) do
      {:ok, %{organisation_id: org_id} = ivf} when org_id == org.id -> {:ok, ivf}
      _ -> {:error, :not_found}
    end
  end

  defp validate_type(type) do
    case Map.fetch(@type_atoms, type) do
      {:ok, atom} -> {:ok, atom}
      :error -> {:error, :invalid_type}
    end
  end

  defp request_upload(org, ivf, type_atom, params) do
    Compliance.request_evidence_upload(%{
      organisation_id: org.id,
      individual_verification_id: ivf.id,
      type: type_atom,
      content_type: Map.get(params, "content_type", "application/octet-stream")
    })
  end

  defp audit(conn, org, ivf, item) do
    FounderPad.Audit.log(:create, "EvidenceItem", item.id, nil, org.id,
      metadata: %{
        event: "evidence.upload_requested",
        actor_type: "api_key",
        api_key_id: conn.assigns.api_key.id,
        verification_id: ivf.id,
        type: item.type
      }
    )
  end

  defp require_scope(conn, scope) do
    scopes = conn.assigns.api_key.scopes
    wanted = String.to_existing_atom(scope)

    if wanted in scopes or :admin in scopes do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{
        error: %{
          code: "permission_denied",
          message: "This API key lacks the required `#{scope}` scope.",
          request_id: RequestId.get(conn)
        }
      })
      |> halt()
    end
  end
end
