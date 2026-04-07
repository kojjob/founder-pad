defmodule LinkHubWeb.PageController do
  @moduledoc "Static page controller."
  use LinkHubWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
