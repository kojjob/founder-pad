defmodule FounderPad.Compliance.MeteringTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory
  require Ash.Query

  alias FounderPad.Compliance.Metering

  defp usage(org, event_type) do
    FounderPad.Billing.UsageRecord
    |> Ash.Query.filter(organisation_id == ^org.id and event_type == ^event_type)
    |> Ash.read!()
  end

  test "records a billable usage event for a live verification" do
    org = create_organisation!()

    {:ok, _} = Metering.meter(org.id, "individual_verification", :live)

    assert [record] = usage(org, "individual_verification")
    assert record.quantity == 1
    assert record.metadata["mode"] == "live"
    assert record.metadata["billable"] == true
  end

  test "test-mode usage is recorded but not billable" do
    org = create_organisation!()

    {:ok, _} = Metering.meter(org.id, "business_verification", :test)

    assert [record] = usage(org, "business_verification")
    assert record.metadata["billable"] == false
  end
end
