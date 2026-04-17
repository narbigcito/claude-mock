defmodule ClaudeMockWeb.AdminLive.DashboardLive do
  use ClaudeMockWeb, :live_view

  alias ClaudeMock.Chats
  alias ClaudeMockWeb.ChatComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin")
     |> assign(:conversations, Chats.list_conversations())
     |> load_rows()}
  end

  defp load_rows(socket) do
    assign(socket, :rows, Chats.list_conversations_with_counts())
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    conv = Chats.get_conversation!(id)
    {:ok, _} = Chats.delete_conversation(conv)

    {:noreply,
     socket
     |> put_flash(:info, "Conversación eliminada.")
     |> assign(:conversations, Chats.list_conversations())
     |> load_rows()}
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
        <header class="flex h-14 items-center justify-between border-b border-claude-border px-6">
          <h1 class="text-[15px] font-medium">Administración</h1>
          <div class="flex items-center gap-2">
            <.link
              navigate={~p"/admin/from-image"}
              class="flex items-center gap-2 rounded-lg border border-claude-border px-3 py-1.5 text-sm font-medium text-claude-text hover:bg-claude-hover"
            >
              <.icon name="hero-photo" class="h-4 w-4" /> Desde imagen
            </.link>
            <.link
              navigate={~p"/admin/new"}
              class="flex items-center gap-2 rounded-lg bg-claude-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-claude-accenthover"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> Nueva conversación
            </.link>
          </div>
        </header>

        <div class="mx-auto w-full max-w-4xl px-6 py-8">
          <%= if @rows == [] do %>
            <div class="rounded-lg border border-claude-border bg-claude-panel/50 p-8 text-center text-sm text-claude-textmuted">
              No hay conversaciones todavía. Crea una con el botón de arriba.
            </div>
          <% else %>
            <div class="overflow-hidden rounded-lg border border-claude-border">
              <table class="w-full text-sm">
                <thead class="bg-claude-panel text-left text-xs uppercase tracking-wider text-claude-textmuted">
                  <tr>
                    <th class="px-4 py-3 font-semibold">Título</th>
                    <th class="px-4 py-3 font-semibold">Modelo</th>
                    <th class="px-4 py-3 text-right font-semibold">Mensajes</th>
                    <th class="px-4 py-3 font-semibold">Actualizada</th>
                    <th class="px-4 py-3"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    :for={row <- @rows}
                    class="border-t border-claude-border hover:bg-claude-hover/40"
                  >
                    <td class="px-4 py-3">
                      <.link
                        navigate={~p"/c/#{row.conversation.id}"}
                        class="text-claude-text hover:underline"
                      >
                        {row.conversation.title}
                      </.link>
                    </td>
                    <td class="px-4 py-3 text-claude-textmuted">
                      {row.conversation.model || "—"}
                    </td>
                    <td class="px-4 py-3 text-right text-claude-textmuted">
                      {row.message_count}
                    </td>
                    <td class="px-4 py-3 text-claude-textmuted">
                      {Calendar.strftime(row.conversation.updated_at, "%Y-%m-%d %H:%M")}
                    </td>
                    <td class="px-4 py-3 text-right">
                      <div class="flex items-center justify-end gap-3 text-xs">
                        <.link
                          navigate={~p"/admin/#{row.conversation.id}/edit"}
                          class="text-claude-textmuted hover:text-claude-text"
                        >
                          Editar
                        </.link>
                        <button
                          type="button"
                          phx-click="delete"
                          phx-value-id={row.conversation.id}
                          data-confirm={"¿Eliminar «#{row.conversation.title}»?"}
                          class="text-claude-textmuted hover:text-red-400"
                        >
                          Eliminar
                        </button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end
end
