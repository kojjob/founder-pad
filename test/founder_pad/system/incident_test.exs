defmodule FounderPad.System.IncidentTest do
  use FounderPad.DataCase, async: true

  alias FounderPad.System.Incident
  import FounderPad.Factory

  describe "create action" do
    test "creates an incident with required fields" do
      admin = create_admin_user!()

      assert {:ok, incident} =
               Incident
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   title: "API Degradation",
                   description: "API response times elevated",
                   severity: :major,
                   affected_components: ["API", "Dashboard"]
                 }, actor: admin)
               |> Ash.create()

      assert incident.title == "API Degradation"
      assert incident.status == :investigating
      assert incident.severity == :major
      assert incident.affected_components == ["API", "Dashboard"]
    end

    test "defaults to investigating status" do
      admin = create_admin_user!()

      {:ok, incident} =
        Incident
        |> Ash.Changeset.for_create(:create, %{title: "Test Incident"}, actor: admin)
        |> Ash.create()

      assert incident.status == :investigating
    end

    test "defaults to minor severity" do
      admin = create_admin_user!()

      {:ok, incident} =
        Incident
        |> Ash.Changeset.for_create(:create, %{title: "Test Incident"}, actor: admin)
        |> Ash.create()

      assert incident.severity == :minor
    end

    test "non-admin cannot create incidents" do
      user = create_user!()

      assert {:error, %Ash.Error.Forbidden{}} =
               Incident
               |> Ash.Changeset.for_create(:create, %{title: "Test"}, actor: user)
               |> Ash.create()
    end
  end

  describe "update action" do
    test "admin can update incident status" do
      admin = create_admin_user!()

      incident =
        Incident
        |> Ash.Changeset.for_create(:create, %{title: "API Down", severity: :critical},
          actor: admin
        )
        |> Ash.create!()

      {:ok, updated} =
        incident
        |> Ash.Changeset.for_update(:update, %{status: :identified}, actor: admin)
        |> Ash.update()

      assert updated.status == :identified
    end
  end

  describe "resolve action" do
    test "resolving sets status to resolved and resolved_at timestamp" do
      admin = create_admin_user!()

      incident =
        Incident
        |> Ash.Changeset.for_create(:create, %{title: "Issue", severity: :minor}, actor: admin)
        |> Ash.create!()

      {:ok, resolved} =
        incident
        |> Ash.Changeset.for_update(:resolve, %{}, actor: admin)
        |> Ash.update()

      assert resolved.status == :resolved
      assert resolved.resolved_at != nil
    end
  end

  describe "active action" do
    test "returns only non-resolved incidents" do
      admin = create_admin_user!()

      # Create active incident
      Incident
      |> Ash.Changeset.for_create(:create, %{title: "Active", severity: :major}, actor: admin)
      |> Ash.create!()

      # Create and resolve an incident
      resolved =
        Incident
        |> Ash.Changeset.for_create(:create, %{title: "Resolved", severity: :minor}, actor: admin)
        |> Ash.create!()

      resolved
      |> Ash.Changeset.for_update(:resolve, %{}, actor: admin)
      |> Ash.update!()

      {:ok, active_incidents} =
        Incident
        |> Ash.Query.for_read(:active)
        |> Ash.read(authorize?: false)

      assert length(active_incidents) == 1
      assert hd(active_incidents).title == "Active"
    end
  end

  describe "recent action" do
    test "returns incidents ordered by most recent first" do
      admin = create_admin_user!()

      Incident
      |> Ash.Changeset.for_create(:create, %{title: "First"}, actor: admin)
      |> Ash.create!()

      Incident
      |> Ash.Changeset.for_create(:create, %{title: "Second"}, actor: admin)
      |> Ash.create!()

      {:ok, incidents} =
        Incident
        |> Ash.Query.for_read(:recent)
        |> Ash.read(authorize?: false)

      assert length(incidents) == 2
      assert hd(incidents).title == "Second"
    end
  end

  describe "read policy" do
    test "anyone can read incidents" do
      admin = create_admin_user!()
      user = create_user!()

      Incident
      |> Ash.Changeset.for_create(:create, %{title: "Public Incident"}, actor: admin)
      |> Ash.create!()

      {:ok, incidents} =
        Incident
        |> Ash.Query.for_read(:recent)
        |> Ash.read(actor: user)

      assert incidents != []
    end
  end
end
