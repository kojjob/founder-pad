defmodule FounderPad.Compliance.RetentionTest do
  use FounderPad.DataCase, async: true
  import FounderPad.Factory

  alias FounderPad.Compliance.{EvidenceItem, Retention}

  # Run retention "100 days from now" so today's records are past their windows.
  defp future, do: DateTime.add(DateTime.utc_now(), 100 * 86_400, :second)

  defp webhook_delivery(org) do
    wh =
      FounderPad.Webhooks.OutboundWebhook
      |> Ash.Changeset.for_create(:create, %{
        url: "https://e.com/wh",
        secret: "s",
        events: [],
        organisation_id: org.id
      })
      |> Ash.create!()

    FounderPad.Webhooks.WebhookDelivery
    |> Ash.Changeset.for_create(:create, %{
      event_type: "x.y",
      payload: %{"sensitive" => "data"},
      webhook_id: wh.id
    })
    |> Ash.create!()
  end

  test "redacts webhook payloads older than the retention window" do
    org = create_organisation!()
    delivery = webhook_delivery(org)
    assert delivery.payload != %{}

    Retention.run(future())

    reloaded = Ash.get!(FounderPad.Webhooks.WebhookDelivery, delivery.id)
    assert reloaded.payload == %{}
  end

  test "marks expired evidence as deleted" do
    org = create_organisation!()

    {:ok, item} =
      EvidenceItem
      |> Ash.Changeset.for_create(:request_upload, %{
        organisation_id: org.id,
        type: :selfie,
        content_type: "image/jpeg"
      })
      |> Ash.create()

    assert item.status == :pending_upload

    Retention.run(future())

    assert Ash.get!(EvidenceItem, item.id).status == :deleted
  end

  test "leaves fresh records untouched" do
    org = create_organisation!()
    delivery = webhook_delivery(org)

    # Run retention "now" — nothing is past its window yet.
    Retention.run(DateTime.utc_now())

    assert Ash.get!(FounderPad.Webhooks.WebhookDelivery, delivery.id).payload != %{}
  end
end
