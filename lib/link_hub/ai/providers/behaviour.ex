defmodule LinkHub.AI.Providers.Behaviour do
  @moduledoc """
  Behaviour contract for AI provider implementations.
  Each provider (Anthropic, OpenAI) implements this behaviour.
  """

  @type message :: %{role: String.t(), content: String.t()}
  @type tool :: %{name: String.t(), description: String.t(), input_schema: map()}
  @type stream_chunk :: %{type: :text | :tool_use | :done, content: String.t() | map()}

  @callback chat(messages :: [message()], opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @callback stream(messages :: [message()], opts :: keyword()) ::
              {:ok, Enumerable.t()} | {:error, term()}

  @callback models() :: [String.t()]
end
