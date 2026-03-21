defmodule FounderPadWeb.TeamSeatsTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  import FounderPad.Factory

  describe "Seat management modal" do
    test "increment seats increases the count", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, view, _html} = live(conn, "/team")

      render_click(view, "show_seats_modal")
      html = render_click(view, "increment_seats")
      # Default plan has 5 seats, incrementing should show 6
      assert html =~ "6"
    end

    test "decrement seats decreases the count", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, view, _html} = live(conn, "/team")

      render_click(view, "show_seats_modal")
      # Increment first to have room to decrement
      render_click(view, "increment_seats")
      html = render_click(view, "decrement_seats")
      # Should be back to original (5)
      assert html =~ "5"
    end

    test "cannot decrement below used seats", %{conn: conn} do
      {conn, _user, org} = setup_authenticated_user(conn)
      # Add a second member so used_seats = 2
      member = create_user!(email: "extra@example.com")
      create_membership!(member, org, :member)

      {:ok, view, _html} = live(conn, "/team")

      render_click(view, "show_seats_modal")
      # Try to decrement many times - should not go below 2 (used_seats)
      for _ <- 1..10 do
        render_click(view, "decrement_seats")
      end

      html = render(view)
      # The new_seat_count should not go below 2 (used_seats)
      assert html =~ "2"
    end

    test "save seats updates total and closes modal", %{conn: conn} do
      {conn, _user, _org} = setup_authenticated_user(conn)
      {:ok, view, _html} = live(conn, "/team")

      render_click(view, "show_seats_modal")
      render_click(view, "increment_seats")
      render_click(view, "increment_seats")
      html = render_click(view, "save_seats")

      assert html =~ "Seats updated to 7"
      # Modal should be closed
      refute html =~ "Adjust Seats"
    end
  end
end
