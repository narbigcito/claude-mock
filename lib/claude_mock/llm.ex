defmodule ClaudeMock.LLM do
  @moduledoc """
  Thin client for the OpenAI-compatible LLM provider used to turn
  screenshots of Claude conversations into our JSON payload.

  Config comes from `config/runtime.exs`:

      config :claude_mock, ClaudeMock.LLM,
        base_url: "https://.../v1",
        api_key:  "sk-...",
        model:    "kimi-k2-turbo-preview"
  """

  @system_prompt """
  You convert screenshots of Claude.ai conversations into a strict JSON document.

  The schema is:

  {
    "title": string,            // A short descriptive title for the conversation
    "model": string|null,       // e.g. "claude-opus-4-6" if visible, otherwise null
    "messages": [
      { "position": integer,    // 0-based, in the order they appear in the screenshot
        "role": "user"|"assistant",
        "content": string       // Markdown is allowed. Preserve code blocks, lists, emphasis.
      }
    ]
  }

  Rules:
  - Respond with the JSON document ONLY. No prose, no markdown fences.
  - Include every visible turn. Merge multi-part messages from the same role into one message.
  - Never invent content that is not visible in the screenshot.
  - If unsure about a short title, derive one from the user's first message.
  - Use "user" for the human and "assistant" for Claude's replies.
  """

  @doc """
  Given a raw image binary and its MIME type (e.g. `"image/png"`),
  calls the provider and returns `{:ok, payload_map}` in our schema,
  or `{:error, reason}` on failure.
  """
  def screenshot_to_payload(image_binary, content_type) when is_binary(image_binary) do
    with {:ok, cfg} <- config(),
         {:ok, body} <- post_chat(cfg, build_messages(image_binary, content_type)),
         {:ok, text} <- extract_text(body),
         {:ok, json} <- decode_json(text) do
      {:ok, json}
    end
  end

  # -- internal --

  defp config do
    cfg = Application.get_env(:claude_mock, __MODULE__, [])

    case {cfg[:base_url], cfg[:api_key], cfg[:model]} do
      {base, key, model} when is_binary(base) and is_binary(key) and key != "" and is_binary(model) ->
        {:ok, %{base_url: base, api_key: key, model: model}}

      _ ->
        {:error, "LLM no configurado: define PANOPTIKON_API_KEY (y opcionalmente PANOPTIKON_BASE_URL / PANOPTIKON_MODEL)."}
    end
  end

  defp build_messages(image_binary, content_type) do
    b64 = Base.encode64(image_binary)
    data_url = "data:#{content_type};base64,#{b64}"

    [
      %{role: "system", content: @system_prompt},
      %{
        role: "user",
        content: [
          %{type: "text", text: "Convierte esta captura en el JSON indicado."},
          %{type: "image_url", image_url: %{url: data_url}}
        ]
      }
    ]
  end

  defp post_chat(cfg, messages) do
    url = String.trim_trailing(cfg.base_url, "/") <> "/chat/completions"

    body = %{
      model: cfg.model,
      messages: messages,
      temperature: 0.2,
      response_format: %{type: "json_object"}
    }

    case Req.post(url,
           headers: [{"authorization", "Bearer #{cfg.api_key}"}],
           json: body,
           receive_timeout: 120_000
         ) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status, body: body}} -> {:error, "LLM HTTP #{status}: #{inspect(body)}"}
      {:error, reason} -> {:error, "LLM request failed: #{inspect(reason)}"}
    end
  end

  defp extract_text(%{"choices" => [%{"message" => %{"content" => text}} | _]}) when is_binary(text),
    do: {:ok, text}

  defp extract_text(other), do: {:error, "Respuesta inesperada del LLM: #{inspect(other)}"}

  # Some models wrap JSON in ```json ... ``` fences even when asked not to.
  defp decode_json(text) do
    text
    |> strip_fences()
    |> Jason.decode()
    |> case do
      {:ok, map} -> {:ok, map}
      {:error, %Jason.DecodeError{} = e} -> {:error, "El LLM no devolvió JSON válido: #{Exception.message(e)}"}
    end
  end

  defp strip_fences(text) do
    text
    |> String.trim()
    |> String.replace(~r/\A```(?:json)?\s*/i, "")
    |> String.replace(~r/\s*```\z/, "")
    |> String.trim()
  end
end
