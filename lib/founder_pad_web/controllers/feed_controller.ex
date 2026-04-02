defmodule FounderPadWeb.FeedController do
  use FounderPadWeb, :controller

  def blog_feed(conn, _params), do: send_resp(conn, 200, "")
  def changelog_feed(conn, _params), do: send_resp(conn, 200, "")
end
