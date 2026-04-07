defmodule FounderPad.FeatureConfigTest do
  use ExUnit.Case, async: true

  alias FounderPad.FeatureConfig

  test "ai_enabled? returns configured value" do
    assert FeatureConfig.ai_enabled?() == true
  end
end
