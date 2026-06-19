defmodule FounderPadWeb.Api.V1.OpenApiController do
  @moduledoc "Serves the GhanaTrust /v1 OpenAPI document (public, no API key)."
  use FounderPadWeb, :controller

  def show(conn, _params) do
    json(conn, FounderPadWeb.Api.OpenApi.spec())
  end
end
