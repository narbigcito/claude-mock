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
         |> assign(:page_title, conversation.title)}

      :error ->
        {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end

  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :conversation, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen w-screen overflow-hidden bg-claude-bg text-claude-text">
      <ChatComponents.sidebar
        conversations={@conversations}
        selected_id={@conversation && @conversation.id}
        current_user={assigns[:current_user]}
      />

      <main class="flex min-w-0 flex-1 flex-col">
        <header class="flex h-14 items-center border-b border-claude-border px-6">
          <h1 class="truncate text-[15px] font-medium text-claude-text">
            {(@conversation && @conversation.title) || "Claude Mock"}
          </h1>
          <span :if={@conversation && @conversation.model} class="ml-3 rounded-full border border-claude-border px-2 py-0.5 text-[11px] text-claude-textmuted">
            {@conversation.model}
          </span>
        </header>

        <%= if @conversation do %>
          <div
            id={"chat-" <> @conversation.id}
            phx-hook="Highlight"
            class="flex-1 overflow-y-auto"
          >
            <div class="mx-auto w-full max-w-3xl space-y-6 px-4 py-8">
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
    </div>
    """
  end
end
