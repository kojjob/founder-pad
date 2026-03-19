defmodule FounderPadWeb.PageController do
  use FounderPadWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
