defmodule ClaudeMockWeb.AdminLive.ConversationFromImageLive do
  use ClaudeMockWeb, :live_view

  alias ClaudeMock.{Chats, LLM}
  alias ClaudeMockWeb.ChatComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Importar desde imagen")
     |> assign(:conversations, Chats.list_conversations())
     |> assign(:json_input, "")
     |> assign(:error, nil)
     |> assign(:generating?, false)
     |> allow_upload(:screenshot,
       accept: ~w(.png .jpg .jpeg .webp),
       max_entries: 1,
       max_file_size: 5_000_000
     )}
  end

  @impl true
  def handle_event("validate-upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", %{"json" => json}, socket) do
    {:noreply, assign(socket, json_input: json, error: nil)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :screenshot, ref)}
  end

  def handle_event("generate", _params, socket) do
    case uploaded_payload(socket) do
      {:ok, binary, content_type} ->
        send(self(), {:run_llm, binary, content_type})
        {:noreply, assign(socket, generating?: true, error: nil)}

      {:error, :none} ->
        {:noreply, assign(socket, error: "Sube una imagen primero.")}
    end
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
        {:noreply, assign(socket, error: "No se pudo guardar: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_info({:run_llm, binary, content_type}, socket) do
    case LLM.screenshot_to_payload(binary, content_type) do
      {:ok, payload} ->
        {:noreply,
         socket
         |> assign(:generating?, false)
         |> assign(:json_input, Jason.encode!(payload, pretty: true))
         |> assign(:error, nil)}

      {:error, msg} ->
        {:noreply,
         socket
         |> assign(:generating?, false)
         |> assign(:error, msg)}
    end
  end

  # -- helpers --

  defp uploaded_payload(socket) do
    # consume_uploaded_entries returns a list of the mapped values.
    case consume_uploaded_entries(socket, :screenshot, fn %{path: path}, entry ->
           {:ok, {File.read!(path), entry.client_type}}
         end) do
      [{binary, type}] -> {:ok, binary, type}
      [] -> {:error, :none}
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

  defp err_label(:too_large), do: "Archivo demasiado grande (máx 5 MB)."
  defp err_label(:not_accepted), do: "Formato no aceptado. Usa PNG, JPG o WEBP."
  defp err_label(:too_many_files), do: "Solo se permite una imagen."
  defp err_label(other), do: to_string(other)

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
          <h1 class="text-[15px] font-medium">Importar desde imagen</h1>
        </header>

        <div class="mx-auto w-full max-w-3xl px-6 py-8 space-y-6">
          <p class="text-sm text-claude-textmuted">
            Sube una captura de una conversación con Claude. El modelo la leerá y generará el JSON con nuestro formato. Revísalo antes de guardar.
          </p>

          <form
            id="upload-form"
            phx-change="validate-upload"
            phx-submit="generate"
            class="space-y-3"
          >
            <label
              for={@uploads.screenshot.ref}
              phx-drop-target={@uploads.screenshot.ref}
              class="flex cursor-pointer flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-claude-border bg-claude-panel/40 px-4 py-10 text-sm text-claude-textmuted hover:border-claude-accent hover:text-claude-text"
            >
              <.icon name="hero-photo" class="h-6 w-6" />
              <span>Arrastra una imagen o haz click para seleccionarla</span>
              <span class="text-xs text-claude-textfaint">PNG, JPG o WEBP — hasta 5 MB</span>
              <.live_file_input upload={@uploads.screenshot} class="sr-only" />
            </label>

            <div
              :for={entry <- @uploads.screenshot.entries}
              class="flex items-center gap-3 rounded-lg border border-claude-border bg-claude-panel/60 px-3 py-2 text-sm"
            >
              <.icon name="hero-document" class="h-4 w-4 text-claude-textmuted" />
              <span class="flex-1 truncate">{entry.client_name}</span>
              <span class="text-xs text-claude-textmuted">{entry.progress}%</span>
              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                class="text-claude-textmuted hover:text-red-400"
              >
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>

            <div
              :for={err <- upload_errors(@uploads.screenshot)}
              class="rounded-lg border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-300"
            >
              {err_label(err)}
            </div>

            <div class="flex justify-end">
              <button
                type="submit"
                disabled={@generating? or @uploads.screenshot.entries == []}
                class="rounded-lg bg-claude-accent px-4 py-2 text-sm font-medium text-white hover:bg-claude-accenthover disabled:cursor-not-allowed disabled:opacity-50"
              >
                {if @generating?, do: "Generando…", else: "Generar JSON"}
              </button>
            </div>
          </form>

          <form phx-change="validate" phx-submit="save" class="space-y-4">
            <label class="block text-sm text-claude-textmuted">
              JSON generado (editable)
            </label>
            <textarea
              name="json"
              rows="22"
              spellcheck="false"
              placeholder="Aquí aparecerá el JSON tras generar…"
              class="w-full rounded-lg border border-claude-border bg-[#1a1a18] px-3 py-2 font-mono text-[13px] leading-5 text-claude-text focus:border-claude-accent focus:outline-none focus:ring-0"
            ><%= @json_input %></textarea>

            <div
              :if={@error}
              class="rounded-lg border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-300"
            >
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
                disabled={@json_input == ""}
                class="rounded-lg bg-claude-accent px-4 py-2 text-sm font-medium text-white hover:bg-claude-accenthover disabled:cursor-not-allowed disabled:opacity-50"
              >
                Guardar conversación
              </button>
            </div>
          </form>
        </div>
      </main>
    </div>
    """
  end
end
