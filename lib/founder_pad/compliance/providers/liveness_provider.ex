defmodule FounderPad.Compliance.Providers.LivenessProvider do
  @moduledoc """
  Behaviour for selfie/liveness and face-match providers. Implementations normalize
  a provider's response into a `t:result/0`. Swappable by config (`:liveness_provider`).
  """

  @type input :: %{required(:reference) => String.t()}

  @type result :: %{
          status: :passed | :failed | :requires_review,
          confidence_score: float(),
          reason_codes: [String.t()],
          provider_name: String.t(),
          provider_reference: String.t()
        }

  @callback check(input()) :: {:ok, result()} | {:error, atom()}
  @callback name() :: String.t()
end
