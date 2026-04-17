defmodule ClaudeMockWeb.AdminLive.ConversationNewLive do
  use ClaudeMockWeb, :live_view

  alias ClaudeMock.Chats
  alias ClaudeMockWeb.ChatComponents

  @sample_json ~S"""
  {
    "title": "Título de la conversación",
    "model": "claude-opus-4-6",
    "messages": [
      {"position": 0, "role": "user",      "content": "Hola"},
      {"position": 1, "role": "assistant", "content": "¡Hola! ¿En qué puedo ayudarte?"}
    ]
  }
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Nueva conversación")
     |> assign(:conversations, Chats.list_conversations())
     |> assign(:json_input, @sample_json)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("validate", %{"json" => json}, socket) do
    {:noreply, assign(socket, json_input: json, error: nil)}
  end

  def handle_event("save", %{"json" => json}, socket) do
    with {:decode, {:ok, payload}} <- {:decode, Jason.decode(json)},
         {:shape, :ok} <- {:shape, validate_shape(payload)},
         {:insert, {:ok, conv}} <- {:insert, Chats.import_conversation(payload)} do
      {:noreply,
       socket
       |> put_flash(:info, "Conversación creada.")
       |> push_navigate(to: ~p"/c/#{conv.id}")}
    else
      {:decode, {:error, %Jason.DecodeError{} = err}} ->
        {:noreply, assign(socket, error: "JSON inválido: #{Exception.message(err)}")}

      {:shape, {:error, msg}} ->
        {:noreply, assign(socket, error: msg)}

      {:insert, {:error, changeset}} ->
        {:noreply,
         assign(socket,
           error: "No se pudo guardar: #{inspect(changeset.errors)}"
         )}
    end
  end

  defp validate_shape(payload) do
    cond do
      not is_map(payload) ->
        {:error, "El JSON debe ser un objeto."}

      not is_binary(payload["title"]) or payload["title"] == "" ->
        {:error, "Falta el campo `title`."}

      not is_list(payload["messages"]) ->
        {:error, "El campo `messages` debe ser una lista."}

      true ->
        :ok
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen w-screen overflow-hidden bg-claude-bg text-claude-text">
      <ChatComponents.sidebar
        conversations={@conversations}
        selected_id={nil}
        current_user={@current_user}
      />

      <main class="flex min-w-0 flex-1 flex-col overflow-y-auto">
        <header class="flex h-14 items-center gap-3 border-b border-claude-border px-6">
          <.link navigate={~p"/admin"} class="text-claude-textmuted hover:text-claude-text">
            <.icon name="hero-arrow-left" class="h-5 w-5" />
          </.link>
          <h1 class="text-[15px] font-medium">Nueva conversación</h1>
        </header>

        <div class="mx-auto w-full max-w-3xl px-6 py-8">
          <p class="mb-4 text-sm text-claude-textmuted">
            Pega un JSON con el formato estándar de Claude Mock. Requerido:
            <code class="rounded bg-claude-panel px-1 py-0.5 text-xs">title</code>
            y <code class="rounded bg-claude-panel px-1 py-0.5 text-xs">messages</code>
            (cada uno con <code class="rounded bg-claude-panel px-1 py-0.5 text-xs">role</code>
            ∈ <code>user|assistant</code> y
            <code class="rounded bg-claude-panel px-1 py-0.5 text-xs">content</code>).
            <br />Opcional:
            <code class="rounded bg-claude-panel px-1 py-0.5 text-xs">position</code>
            por mensaje — si lo incluyes, ese número fija el orden y ya no depende del array.
          </p>

          <form phx-change="validate" phx-submit="save" class="space-y-4">
            <textarea
              name="json"
              rows="22"
              spellcheck="false"
              class="w-full rounded-lg border border-claude-border bg-[#1a1a18] px-3 py-2 font-mono text-[13px] leading-5 text-claude-text focus:border-claude-accent focus:outline-none focus:ring-0"
            ><%= @json_input %></textarea>

            <div :if={@error} class="rounded-lg border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-300">
              {@error}
            </div>

            <div class="flex justify-end gap-2">
              <.link
                navigate={~p"/admin"}
                class="rounded-lg border border-claude-border px-4 py-2 text-sm text-claude-textmuted hover:bg-claude-hover"
              >
                Cancelar
              </.link>
              <button
                type="submit"
                class="rounded-lg bg-claude-accent px-4 py-2 text-sm font-medium text-white hover:bg-claude-accenthover"
              >
                Guardar
              </button>
            </div>
          </form>
        </div>
      </main>
    </div>
    """
  end
end
