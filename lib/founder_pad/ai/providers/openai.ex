defmodule FounderPad.AI.Providers.OpenAI do
  @moduledoc "OpenAI GPT API provider."
  @behaviour FounderPad.AI.Providers.Behaviour

  require Logger

  @base_url "https://api.openai.com/v1"

  @impl true
  def chat(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "gpt-4o")
    system_prompt = Keyword.get(opts, :system_prompt)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)
    temperature = Keyword.get(opts, :temperature, 0.7)

    formatted = format_messages(messages, system_prompt)

    body = %{
      "model" => model,
      "messages" => formatted,
      "max_tokens" => max_tokens,
      "temperature" => temperature
    }

    case make_request("/chat/completions", body) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
        {:ok, content}

      {:ok, response} ->
        {:error, {:unexpected_response, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def stream(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "gpt-4o")
    system_prompt = Keyword.get(opts, :system_prompt)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)
    temperature = Keyword.get(opts, :temperature, 0.7)

    formatted = format_messages(messages, system_prompt)

    body = %{
      "model" => model,
      "messages" => formatted,
      "max_tokens" => max_tokens,
      "temperature" => temperature,
      "stream" => true
    }

    {:ok, stream_request("/chat/completions", body)}
  end

  @impl true
  def models do
    ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o3-mini"]
  end

  defp format_messages(messages, system_prompt) do
    system = if system_prompt, do: [%{"role" => "system", "content" => system_prompt}], else: []

    user_messages =
      Enum.map(messages, fn msg ->
        %{"role" => to_string(msg.role), "content" => msg.content}
      end)

    system ++ user_messages
  end

  defp make_request(path, body) do
    api_key = get_api_key()

    case Req.post("#{@base_url}#{path}",
           json: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ],
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("OpenAI API error #{status}: #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("OpenAI request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp stream_request(path, body) do
    api_key = get_api_key()

    Stream.resource(
      fn ->
        Req.post!("#{@base_url}#{path}",
          json: body,
          headers: [
            {"authorization", "Bearer #{api_key}"},
            {"content-type", "application/json"}
          ],
          into: :self,
          receive_timeout: 120_000
        )
      end,
      fn req ->
        receive do
          {_ref, {:data, data}} ->
            chunks = parse_sse_chunks(data)
            {chunks, req}

          {_ref, :done} ->
            {:halt, req}
        after
          30_000 -> {:halt, req}
        end
      end,
      fn _req -> :ok end
    )
  end

  defp parse_sse_chunks(data) do
    data
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "data: "))
    |> Enum.reject(&(&1 == "data: [DONE]"))
    |> Enum.map(fn "data: " <> json ->
      case Jason.decode(json) do
        {:ok, %{"choices" => [%{"delta" => %{"content" => content}} | _]}} when is_binary(content) ->
          %{type: :text, content: content}

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_api_key do
    Application.get_env(:founder_pad, :ai)[:openai_api_key] ||
      System.get_env("OPENAI_API_KEY") ||
      raise "OPENAI_API_KEY not configured"
  end
end
