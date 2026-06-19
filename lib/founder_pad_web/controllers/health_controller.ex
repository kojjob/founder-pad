defmodule FounderPadWeb.HealthController do
  @moduledoc "Lightweight liveness probe for load balancers / Fly health checks."
  use FounderPadWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
