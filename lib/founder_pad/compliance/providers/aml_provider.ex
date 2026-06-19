defmodule FounderPad.Compliance.Providers.AmlProvider do
  @moduledoc """
  Behaviour for AML screening providers (sanctions / PEP / adverse media).

  Implementations normalize a provider response into a `t:result/0`. By policy a
  name hit is returned as `:possible_match` — providers must not auto-`confirmed_match`;
  a human confirms (no automated final AML decision). Swappable by config (`:aml_provider`).
  """

  @type input :: %{
          required(:name) => String.t(),
          required(:subject_type) => :person | :business
        }

  @type result :: %{
          status: :clear | :possible_match | :confirmed_match | :failed,
          lists_checked: [String.t()],
          match_count: non_neg_integer(),
          highest_confidence: float(),
          reason_codes: [String.t()],
          provider_name: String.t(),
          provider_reference: String.t()
        }

  @callback screen(input()) :: {:ok, result()} | {:error, atom()}
  @callback name() :: String.t()
end
