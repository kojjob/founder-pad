defmodule FounderPad.FeatureConfig do
  @moduledoc "Runtime feature configuration helpers."

  @doc "Returns whether the AI agents feature is enabled."
  @spec ai_enabled?() :: boolean()
  def ai_enabled?, do: Application.get_env(:founder_pad, :ai_enabled, true)
end
