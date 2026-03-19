defmodule FounderPad.RateLimit do
  @moduledoc """
  Rate limiter backed by Hammer ETS.

  Started as a child in the application supervision tree.
  Provides `hit/3` to check and increment rate limit counters.
  """
  use Hammer, backend: :ets
end
