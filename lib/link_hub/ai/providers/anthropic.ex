defmodule LinkHub.AI.Providers.Anthropic do
  @moduledoc "Anthropic Claude API provider."
  @behaviour LinkHub.AI.Providers.Behaviour

  require Logger

  @base_url "https://api.anthropic.com/v1"
  @api_version "2023-06-01"

  @impl true
  def chat(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "claude-sonnet-4-20250514")
    system_prompt = Keyword.get(opts, :system_prompt)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)
    temperature = Keyword.get(opts, :temperature, 0.7)

    body = build_request_body(messages, model, system_prompt, max_tokens, temperature)

    case make_request("/messages", body) do
      {:ok, %{"content" => [%{"text" => text} | _]}} ->
        {:ok, text}

      {:ok, response} ->
        {:error, {:unexpected_response, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def stream(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "claude-sonnet-4-20250514")
    system_prompt = Keyword.get(opts, :system_prompt)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)
    temperature = Keyword.get(opts, :temperature, 0.7)

    body =
      build_request_body(messages, model, system_prompt, max_tokens, temperature)
      |> Map.put("stream", true)

    # Returns a stream that can be consumed by the caller
    {:ok, stream_request("/messages", body)}
  end

  @impl true
  def models do
    [
      "claude-sonnet-4-20250514",
      "claude-opus-4-20250514",
      "claude-haiku-4-20250414"
    ]
  end

  defp build_request_body(messages, model, system_prompt, max_tokens, temperature) do
    body = %{
      "model" => model,
      "max_tokens" => max_tokens,
      "temperature" => temperature,
      "messages" => format_messages(messages)
    }

    if system_prompt, do: Map.put(body, "system", system_prompt), else: body
  end

  defp format_messages(messages) do
    Enum.map(messages, fn msg ->
      %{"role" => to_string(msg.role), "content" => msg.content}
    end)
  end

  defp make_request(path, body) do
    api_key = get_api_key()

    case Req.post("#{@base_url}#{path}",
           json: body,
           headers: [
             {"x-api-key", api_key},
             {"anthropic-version", @api_version},
             {"content-type", "application/json"}
           ],
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Anthropic API error #{status}: #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("Anthropic request failed: #{inspect(reason)}")
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
            {"x-api-key", api_key},
            {"anthropic-version", @api_version},
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
    |> Enum.map(fn "data: " <> json ->
      case Jason.decode(json) do
        {:ok, %{"type" => "content_block_delta", "delta" => %{"text" => text}}} ->
          %{type: :text, content: text}

        {:ok, %{"type" => "message_stop"}} ->
          %{type: :done, content: ""}

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_api_key do
    Application.get_env(:link_hub, :ai)[:anthropic_api_key] ||
      System.get_env("ANTHROPIC_API_KEY") ||
      raise "ANTHROPIC_API_KEY not configured"
  end
end
