defmodule FounderPad.Compliance.Providers.IdentityProvider do
  @moduledoc """
  Behaviour for Ghana Card / individual identity verification providers.

  Implementations (sandbox today, an approved NIA/partner route later) translate
  a normalized input into a normalized `t:result/0`. No provider-specific concern
  may leak into the core domain — callers depend only on this contract, so a live
  provider can be swapped in by configuration with no business-logic changes.
  """

  @typedoc "Normalized verification input."
  @type input :: %{
          required(:ghana_card_number) => String.t(),
          optional(:first_name) => String.t() | nil,
          optional(:last_name) => String.t() | nil,
          optional(:date_of_birth) => Date.t() | String.t() | nil,
          optional(:phone_number) => String.t() | nil
        }

  @typedoc "Normalized verification result."
  @type result :: %{
          status: :verified | :failed | :requires_review,
          identity_verified: boolean(),
          match_level: :none | :weak | :medium | :strong,
          reason_codes: [String.t()],
          provider_name: String.t(),
          provider_reference: String.t()
        }

  @doc "Verify an identity. Returns a normalized result or an error reason."
  @callback verify(input()) :: {:ok, result()} | {:error, atom()}

  @doc "The provider's stable name, stored on the verification for explainability."
  @callback name() :: String.t()
end
