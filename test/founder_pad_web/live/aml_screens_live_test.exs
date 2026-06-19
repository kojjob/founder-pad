defmodule FounderPadWeb.AmlScreensLiveTest do
  use FounderPadWeb.ConnCase, async: true
  use FounderPad.LiveViewHelpers

  alias FounderPad.Compliance.AmlScreening
  alias FounderPad.Factory

  test "lists the tenant's AML screens", %{conn: conn} do
    {conn, _user, org} = setup_authenticated_user(conn)
    {:ok, _} = AmlScreening.screen(org.id, :person, Ash.UUID.generate(), "AML-PEP Person")

    {:ok, _view, html} = live(conn, ~p"/aml-screens")

    assert html =~ "AML Screening"
    assert html =~ "possible_match"
  end

  test "does not show another tenant's screens", %{conn: conn} do
    {conn, _user, _org} = setup_authenticated_user(conn)
    other = Factory.create_organisation!()
    {:ok, _} = AmlScreening.screen(other.id, :person, Ash.UUID.generate(), "AML-SANCTION X")

    {:ok, _view, html} = live(conn, ~p"/aml-screens")
    # The other tenant's screen exists but must not leak; this tenant has none.
    assert html =~ "No AML screens"
  end
end
