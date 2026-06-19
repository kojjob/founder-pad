defmodule FounderPad.Compliance.Providers.KybProvider do
  @moduledoc """
  Behaviour for business verification (KYB) providers. Implementations normalize a
  registry/provider response into a `t:result/0`. Swappable by config (`:kyb_provider`).
  """

  @type input :: %{
          required(:registration_number) => String.t(),
          optional(:registered_name) => String.t() | nil,
          optional(:tin) => String.t() | nil
        }

  @type result :: %{
          status: :verified | :failed | :requires_review,
          risk_level: :low | :medium | :high,
          reason_codes: [String.t()],
          provider_name: String.t(),
          provider_reference: String.t()
        }

  @callback verify(input()) :: {:ok, result()} | {:error, atom()}
  @callback name() :: String.t()
end
