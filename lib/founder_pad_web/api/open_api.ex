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
        "get" => %{
          summary: "List individual verifications",
          operationId: "listIndividualVerifications",
          parameters: list_params(),
          responses: %{"200" => json_response("OK", "VerificationList")}
        },
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
          parameters: [id_param()],
          responses: %{
            "200" => json_response("OK", "IndividualVerification"),
            "401" => error_response("Authentication failed"),
            "404" => error_response("Verification not found")
          }
        }
      },
      "/v1/individual_verifications/{id}/evidence_uploads" => %{
        "post" => %{
          summary: "Request a signed URL to upload evidence (selfie/document)",
          operationId: "createEvidenceUpload",
          parameters: [id_param()],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{
                  type: "object",
                  required: ["type"],
                  properties: %{
                    type: %{
                      type: "string",
                      enum: [
                        "selfie",
                        "document_front",
                        "document_back",
                        "proof_of_address",
                        "business_document"
                      ]
                    },
                    content_type: %{type: "string", example: "image/jpeg"}
                  }
                }
              }
            }
          },
          responses: %{
            "201" => json_response("Signed upload URL issued", "EvidenceUpload"),
            "403" => error_response("Permission denied"),
            "404" => error_response("Verification not found"),
            "422" => error_response("Invalid evidence type")
          }
        }
      },
      "/v1/business_verifications" => %{
        "get" => %{
          summary: "List business verifications",
          operationId: "listBusinessVerifications",
          parameters: list_params(),
          responses: %{"200" => json_response("OK", "VerificationList")}
        },
        "post" => %{
          summary: "Create a business (KYB) verification",
          operationId: "createBusinessVerification",
          parameters: [idempotency_key_header()],
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{"$ref" => "#/components/schemas/BusinessVerificationRequest"}
              }
            }
          },
          responses: %{
            "201" => json_response("Created", "BusinessVerification"),
            "200" => json_response("Existing (idempotent)", "BusinessVerification"),
            "401" => error_response("Authentication failed"),
            "403" => error_response("Permission denied"),
            "409" => error_response("Idempotency-Key reused with a different body"),
            "422" => error_response("Validation failed")
          }
        }
      },
      "/v1/business_verifications/{id}" => %{
        "get" => %{
          summary: "Retrieve a business verification",
          operationId: "getBusinessVerification",
          parameters: [id_param()],
          responses: %{
            "200" => json_response("OK", "BusinessVerification"),
            "401" => error_response("Authentication failed"),
            "404" => error_response("Business verification not found")
          }
        }
      },
      "/v1/webhook_endpoints" => %{
        "get" => %{
          summary: "List webhook endpoints",
          operationId: "listWebhookEndpoints",
          parameters: list_params(),
          responses: %{"200" => json_response("OK", "VerificationList")}
        },
        "post" => %{
          summary: "Register a webhook endpoint (secret returned once)",
          operationId: "createWebhookEndpoint",
          requestBody: %{
            required: true,
            content: %{
              "application/json" => %{
                schema: %{
                  type: "object",
                  required: ["url"],
                  properties: %{
                    url: %{type: "string", format: "uri"},
                    events: %{type: "array", items: %{type: "string"}}
                  }
                }
              }
            }
          },
          responses: %{
            "201" => json_response("Created", "WebhookEndpoint"),
            "403" => error_response("Permission denied"),
            "422" => error_response("Validation failed")
          }
        }
      },
      "/v1/webhook_deliveries" => %{
        "get" => %{
          summary: "List webhook deliveries for an endpoint",
          operationId: "listWebhookDeliveries",
          parameters:
            [
              %{
                name: "webhook_endpoint_id",
                in: "query",
                required: true,
                schema: %{type: "string", format: "uuid"}
              }
            ] ++
              list_params(),
          responses: %{
            "200" => json_response("OK", "VerificationList"),
            "404" => error_response("Webhook endpoint not found")
          }
        }
      },
      "/v1/webhook_deliveries/{id}/retry" => %{
        "post" => %{
          summary: "Retry a webhook delivery",
          operationId: "retryWebhookDelivery",
          parameters: [id_param()],
          responses: %{
            "202" => json_response("Retrying", "WebhookEndpoint"),
            "403" => error_response("Permission denied"),
            "404" => error_response("Delivery not found")
          }
        }
      }
    }
  end

  defp id_param do
    %{name: "id", in: "path", required: true, schema: %{type: "string", format: "uuid"}}
  end

  defp list_params do
    [
      %{name: "limit", in: "query", schema: %{type: "integer", default: 20, maximum: 100}},
      %{name: "offset", in: "query", schema: %{type: "integer", default: 0}},
      %{name: "status", in: "query", schema: %{type: "string"}}
    ]
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
            },
            options: %{"$ref" => "#/components/schemas/VerificationOptions"}
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
        "BusinessVerificationRequest" => %{
          type: "object",
          required: ["business"],
          properties: %{
            external_id: %{type: "string"},
            business: %{
              type: "object",
              required: ["registration_number"],
              properties: %{
                registered_name: %{type: "string"},
                registration_number: %{type: "string", example: "CS-TEST-VERIFIED-1"},
                tin: %{type: "string"}
              }
            },
            options: %{"$ref" => "#/components/schemas/VerificationOptions"}
          }
        },
        "VerificationOptions" => %{
          type: "object",
          properties: %{
            require_liveness: %{type: "boolean"},
            run_aml_screen: %{
              type: "boolean",
              description: "Run sanctions/PEP/adverse-media screening; matches route to review."
            }
          }
        },
        "BusinessVerification" => %{
          type: "object",
          properties: %{
            id: %{type: "string", format: "uuid"},
            status: %{type: "string", enum: ["pending", "verified", "failed", "requires_review"]},
            mode: %{type: "string", enum: ["test", "live"]},
            external_id: %{type: "string"},
            business: %{
              type: "object",
              properties: %{registered_name: %{type: "string"}}
            },
            risk: %{
              type: "object",
              properties: %{
                level: %{type: "string", enum: ["low", "medium", "high"]},
                reason_codes: %{type: "array", items: %{type: "string"}}
              }
            },
            created_at: %{type: "string", format: "date-time"},
            completed_at: %{type: "string", format: "date-time", nullable: true}
          }
        },
        "VerificationList" => %{
          type: "object",
          properties: %{
            data: %{type: "array", items: %{type: "object"}},
            pagination: %{
              type: "object",
              properties: %{
                limit: %{type: "integer"},
                offset: %{type: "integer"}
              }
            }
          }
        },
        "WebhookEndpoint" => %{
          type: "object",
          properties: %{
            id: %{type: "string", format: "uuid"},
            url: %{type: "string", format: "uri"},
            events: %{type: "array", items: %{type: "string"}},
            active: %{type: "boolean"},
            secret: %{type: "string", description: "Signing secret — returned only on creation."}
          }
        },
        "EvidenceUpload" => %{
          type: "object",
          properties: %{
            evidence_id: %{type: "string", format: "uuid"},
            upload_url: %{
              type: "string",
              description: "Short-lived signed URL — PUT the bytes here."
            },
            expires_at: %{type: "string", format: "date-time"}
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
