defmodule ClaudeMockWeb.ChatLive do
  use ClaudeMockWeb, :live_view

  alias ClaudeMock.Chats
  alias ClaudeMockWeb.ChatComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:conversations, Chats.list_conversations())
     |> assign(:conversation, nil)
     |> assign(:show_export, false)
     |> assign(:show_sidebar, false)
     |> assign(:base_url, ClaudeMockWeb.Endpoint.url())
     |> assign(:page_title, "Claude")}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        conversation = Chats.get_conversation!(uuid)

        {:noreply,
         socket
         |> assign(:conversation, conversation)
         |> assign(:show_export, false)
         |> assign(:page_title, conversation.title)}

      :error ->
        {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end

  def handle_params(_params, _url, socket) do
    welcome =
      Enum.find(socket.assigns.conversations, fn c ->
        c.title == "Bienvenida a Claude Mock"
      end)

    case welcome || List.first(socket.assigns.conversations) do
      nil ->
        {:noreply, assign(socket, :conversation, nil)}

      conv ->
        {:noreply, push_patch(socket, to: ~p"/c/#{conv.id}")}
    end
  end

  @impl true
  def handle_event("toggle_export", _params, socket) do
    {:noreply, assign(socket, :show_export, !socket.assigns.show_export)}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :show_sidebar, !socket.assigns.show_sidebar)}
  end

  @impl true
  def handle_event("close_sidebar", _params, socket) do
    {:noreply, assign(socket, :show_sidebar, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen w-screen overflow-hidden bg-claude-bg text-claude-text">

      <div
        :if={@show_sidebar}
        class="fixed inset-0 z-40 bg-black/50 lg:hidden"
        phx-click="close_sidebar"
      />

      <ChatComponents.sidebar
        conversations={@conversations}
        selected_id={@conversation && @conversation.id}
        current_user={assigns[:current_user]}
        show_sidebar={@show_sidebar}
        on_close="close_sidebar"
      />

      <main class="flex min-w-0 flex-1 flex-col">
        <header class="flex h-14 items-center border-b border-claude-border px-4 lg:px-6 gap-3">

          <button
            phx-click="toggle_sidebar"
            class="lg:hidden flex h-8 w-8 items-center justify-center rounded-lg text-claude-textmuted hover:bg-claude-hover hover:text-claude-text"
            aria-label="Abrir menú"
          >
            <.icon name="hero-bars-3" class="h-5 w-5" />
          </button>

          <h1 class="truncate text-[15px] font-medium text-claude-text flex-1 min-w-0">
            {(@conversation && @conversation.title) || "Claude Mock"}
          </h1>
          <span
            :if={@conversation && @conversation.model}
            class="hidden sm:inline-flex rounded-full border border-claude-border px-2 py-0.5 text-[11px] text-claude-textmuted shrink-0"
          >
            {@conversation.model}
          </span>
          <button
            :if={@conversation}
            phx-click="toggle_export"
            title="Exportar conversación"
            class="flex items-center gap-1.5 rounded-lg border border-claude-border px-3 py-1.5 text-xs text-claude-textmuted hover:bg-claude-hover hover:text-claude-text transition-colors shrink-0"
          >
            <.icon name="hero-arrow-down-tray" class="h-3.5 w-3.5" />
            <span class="hidden sm:inline">Exportar</span>
          </button>
        </header>

        <%= if @conversation do %>
          <div
            id={"chat-" <> @conversation.id}
            phx-hook="Highlight"
            class="flex-1 overflow-y-auto"
          >
            <div class="mx-auto w-full max-w-3xl space-y-4 sm:space-y-6 px-3 sm:px-4 py-4 sm:py-8">
              <ChatComponents.message :for={m <- @conversation.messages} message={m} />
            </div>
          </div>
        <% else %>
          <div class="flex flex-1 items-center justify-center px-6 text-center">
            <div class="max-w-md">
              <div class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-claude-accent text-white">
                <.icon name="hero-sparkles-solid" class="h-6 w-6" />
              </div>
              <h2 class="font-serif text-2xl text-claude-text">Hola.</h2>
              <p class="mt-2 text-sm text-claude-textmuted">
                Selecciona una conversación de la barra lateral para leerla.
              </p>
            </div>
          </div>
        <% end %>

        <ChatComponents.composer_placeholder />
      </main>

      <div
        :if={@show_export && @conversation}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4"
        phx-click="toggle_export"
      >
        <div
          class="w-full max-w-lg rounded-2xl border border-claude-border bg-claude-panel shadow-2xl p-6"
          phx-click-away="toggle_export"
        >
          <div class="flex items-center justify-between mb-5">
            <h3 class="text-base font-semibold text-claude-text">Exportar conversación</h3>
            <button phx-click="toggle_export" class="text-claude-textmuted hover:text-claude-text">
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>

          <div class="space-y-4">

            <div>
              <p class="text-xs font-medium text-claude-textmuted mb-1.5">
                Código iframe para insertar en otras páginas:
              </p>
              <div class="relative">
                <textarea
                  id="iframe-code"
                  readonly
                  rows="3"
                  onclick="this.select()"
                  class="w-full resize-none rounded-lg bg-claude-bg border border-claude-border px-3 py-2 text-xs font-mono text-claude-textmuted focus:outline-none focus:border-claude-accent"
                ><%= "<iframe src=\"#{@base_url}/embed/#{@conversation.id}\" width=\"100%\" height=\"600\" frameborder=\"0\" style=\"border-radius:12px;overflow:hidden;\"></iframe>" %></textarea>
              </div>
              <button
                onclick="navigator.clipboard.writeText(document.getElementById('iframe-code').value).then(() => { this.textContent = '¡Copiado!'; setTimeout(() => this.textContent = 'Copiar código', 2000) })"
                class="mt-2 text-xs text-claude-accent hover:text-claude-accenthover transition-colors"
              >
                Copiar código
              </button>
            </div>

            <div class="border-t border-claude-border pt-4">
              <p class="text-xs font-medium text-claude-textmuted mb-2">
                Descargar como HTML independiente:
              </p>
              <a
                href={~p"/export/#{@conversation.id}"}
                download={"#{@conversation.title}.html"}
                class="inline-flex items-center gap-2 rounded-lg bg-claude-accent px-4 py-2 text-sm text-white hover:bg-[#b5583a] transition-colors"
              >
                <.icon name="hero-arrow-down-tray" class="h-4 w-4" /> Descargar HTML
              </a>
              <p class="mt-2 text-[11px] text-claude-textfaint">
                El archivo HTML descargado incluye todo el CSS necesario y puede hospedarse en cualquier servidor para usarlo como iframe.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
