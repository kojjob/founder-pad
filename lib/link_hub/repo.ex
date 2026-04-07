defmodule LinkHub.Repo do
  @moduledoc "Ecto repository for PostgreSQL database access."
  use AshPostgres.Repo, otp_app: :link_hub

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext"]
  end

  def min_pg_version do
    %Version{major: 14, minor: 0, patch: 0}
  end
end
