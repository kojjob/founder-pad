defmodule FounderPadWeb.Api.OpenApi do
  @moduledoc """
  Hand-authored OpenAPI 3 document for the GhanaTrust public `/v1` REST API.

  The `/v1` surface is hand-written (not derived from Ash), so its contract is
  described here and served as machine-readable JSON at `GET /v1/openapi.json`.
  Keep this in sync with `FounderPadWeb.Api.V1.*` controllers and `docs/GHANATRUST.md`.
  """

  @version "2026-06-17"

  @spec spec() :: map()
  def spec do
    %{
      openapi: "3.0.3",
      info: %{
        title: "GhanaTrust API",
        version: @version,
        description:
          "Ghana-first KYC/consent/risk verification API. Authenticate with an API key " <>
            "(Bearer). The key's mode (test/live) sets the verification mode."
      },
      servers: [%{url: "/", description: "Same-origin"}],
      security: [%{"ApiKeyAuth" => []}],
      paths: paths(),
      components: components()
    }
  end

  defp paths do
    %{
      "/v1/individual_verifications" => %{
        "post" => %{
          summary: "Create an individual verification",
          operationId: "createIndividualVerification",
          parameters: [idempotency_key_header()],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/IndividualVerificationRequest"}
              }
            }
          },
          responses: %{
            "201" => json_response("Created", "IndividualVerification"),
            "200" =>
              json_response(
                "Existing (idempotent replay or external_id match)",
                "IndividualVerification"
              ),
            "401" => error_response("Authentication failed"),
            "403" => error_response("Permission denied (missing scope)"),
            "409" => error_response("Idempotency-Key reused with a different body"),
            "422" => error_response("Validation failed or consent required")
          }
        }
      },
      "/v1/individual_verifications/{id}" => %{
        "get" => %{
          summary: "Retrieve an individual verification",
          operationId: "getIndividualVerification",
          parameters: [
            %{
              name: "id",
              in: "path",
              required: true,
              schema: %{type: "string", format: "uuid"}
            }
          ],
          responses: %{
            "200" => json_response("OK", "IndividualVerification"),
            "401" => error_response("Authentication failed"),
            "404" => error_response("Verification not found")
          }
        }
      }
    }
  end

  defp components do
    %{
      securitySchemes: %{
        "ApiKeyAuth" => %{
          type: "http",
          scheme: "bearer",
          description: "Your API key, e.g. `Authorization: Bearer fp_...`"
        }
      },
      schemas: %{
        "IndividualVerificationRequest" => %{
          type: "object",
          required: ["person"],
          properties: %{
            external_id: %{
              type: "string",
              description: "Your reference; idempotent within a tenant."
            },
            person: %{
              type: "object",
              required: ["ghana_card_number"],
              properties: %{
                ghana_card_number: %{type: "string", example: "GHA-TEST-VERIFIED-1"},
                first_name: %{type: "string"},
                last_name: %{type: "string"},
                date_of_birth: %{type: "string", format: "date"},
                phone_number: %{type: "string"}
              }
            },
            consent: %{
              type: "object",
              description: "Required in live mode.",
              properties: %{
                purpose: %{type: "string"},
                channel: %{type: "string", enum: ["web", "mobile", "ussd", "sms", "api"]},
                accepted_at: %{type: "string", format: "date-time"},
                privacy_notice_version: %{type: "string"}
              }
            }
          }
        },
        "IndividualVerification" => %{
          type: "object",
          properties: %{
            id: %{type: "string", format: "uuid"},
            status: %{
              type: "string",
              enum: [
                "pending",
                "processing",
                "verified",
                "failed",
                "requires_review",
                "cancelled",
                "expired"
              ]
            },
            mode: %{type: "string", enum: ["test", "live"]},
            external_id: %{type: "string"},
            identity: %{
              type: "object",
              properties: %{
                verified: %{type: "boolean"},
                match_level: %{type: "string", enum: ["none", "weak", "medium", "strong"]},
                provider_reference: %{type: "string"}
              }
            },
            risk: %{
              type: "object",
              properties: %{
                level: %{type: "string", enum: ["low", "medium", "high"]},
                score: %{type: "integer", minimum: 0, maximum: 100},
                reason_codes: %{type: "array", items: %{type: "string"}}
              }
            },
            consent_receipt_id: %{type: "string", format: "uuid", nullable: true},
            created_at: %{type: "string", format: "date-time"},
            completed_at: %{type: "string", format: "date-time", nullable: true}
          }
        },
        "Error" => %{
          type: "object",
          properties: %{
            error: %{
              type: "object",
              properties: %{
                code: %{type: "string"},
                message: %{type: "string"},
                request_id: %{type: "string"}
              }
            }
          }
        }
      }
    }
  end

  defp idempotency_key_header do
    %{
      name: "Idempotency-Key",
      in: "header",
      required: false,
      description: "Safe-retry key. Same key + body replays; different body → 409.",
      schema: %{type: "string"}
    }
  end

  defp json_response(description, schema) do
    %{
      description: description,
      content: %{
        "application/json" => %{schema: %{"$ref" => "#/components/schemas/#{schema}"}}
      }
    }
  end

  defp error_response(description), do: json_response(description, "Error")
end
