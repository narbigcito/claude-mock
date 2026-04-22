defmodule ClaudeMockWeb.ChatComponents do
  @moduledoc false
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: ClaudeMockWeb.Endpoint,
    router: ClaudeMockWeb.Router

  import ClaudeMockWeb.CoreComponents, only: [icon: 1]

  alias ClaudeMockWeb.Markdown

  attr :conversations, :list, required: true
  attr :selected_id, :any, default: nil
  attr :current_user, :any, default: nil
  attr :show_sidebar, :boolean, default: false
  attr :on_close, :string, default: "close_sidebar"

  def sidebar(assigns) do
    ~H"""
    <aside
      class={[
        "fixed lg:static inset-y-0 left-0 z-50 flex h-screen w-64 shrink-0 flex-col border-r border-claude-border bg-claude-sidebar transition-transform duration-300 ease-in-out lg:translate-x-0",
        if(@show_sidebar, do: "translate-x-0", else: "-translate-x-full")
      ]}
    >
      <div class="flex items-center gap-2 px-4 pt-4 pb-3">
        <div class="flex h-7 w-7 items-center justify-center rounded-md bg-claude-accent text-white">
          <.icon name="hero-sparkles-solid" class="h-4 w-4" />
        </div>
        <span class="font-serif text-[17px] text-claude-text flex-1">Claude</span>
        <%# Close button for mobile %>
        <button
          phx-click={@on_close}
          class="lg:hidden flex h-7 w-7 items-center justify-center rounded-md text-claude-textmuted hover:bg-claude-hover hover:text-claude-text"
          aria-label="Cerrar menú"
        >
          <.icon name="hero-x-mark" class="h-5 w-5" />
        </button>
      </div>

      <div class="px-3 pb-3">
        <%= if @current_user && @current_user.is_admin do %>
          <.link
            navigate={~p"/admin/new"}
            class="flex w-full items-center gap-2 rounded-lg border border-claude-border bg-claude-bg/40 px-3 py-2 text-sm text-claude-text hover:bg-claude-hover"
          >
            <.icon name="hero-pencil-square" class="h-4 w-4" />
            Nueva conversación
          </.link>
        <% else %>
          <button
            type="button"
            disabled
            class="flex w-full items-center gap-2 rounded-lg border border-claude-border bg-claude-bg/40 px-3 py-2 text-sm text-claude-textmuted cursor-not-allowed"
            title="Modo solo lectura"
          >
            <.icon name="hero-pencil-square" class="h-4 w-4" />
            Nuevo chat
          </button>
        <% end %>
      </div>

      <div class="px-4 pt-2 pb-1 text-[11px] font-semibold uppercase tracking-wider text-claude-textfaint">
        Recientes
      </div>

      <nav class="flex-1 overflow-y-auto px-2 pb-4">
        <ul class="space-y-0.5">
          <li :for={c <- @conversations}>
            <.link
              patch={~p"/c/#{c.id}"}
              class={[
                "block truncate rounded-lg px-3 py-2 text-sm transition-colors",
                if(@selected_id == c.id,
                  do: "bg-claude-panel text-claude-text",
                  else: "text-claude-textmuted hover:bg-claude-hover hover:text-claude-text")
              ]}
            >
              {c.title}
            </.link>
          </li>
          <li :if={@conversations == []}>
            <div class="px-3 py-6 text-center text-xs text-claude-textfaint">
              No hay conversaciones todavía.
            </div>
          </li>
        </ul>
      </nav>

      <div class="border-t border-claude-border px-3 py-3 text-xs text-claude-textmuted">
        <%= if @current_user do %>
          <div class="flex items-center justify-between gap-2">
            <span class="truncate">{@current_user.email}</span>
            <.link href={~p"/users/log_out"} method="delete" class="hover:text-claude-text">
              Salir
            </.link>
          </div>
          <.link
            :if={@current_user.is_admin}
            navigate={~p"/admin"}
            class="mt-2 flex items-center gap-1.5 text-claude-textmuted hover:text-claude-text"
          >
            <.icon name="hero-cog-6-tooth" class="h-3.5 w-3.5" /> Admin
          </.link>
        <% else %>
          <.link href={~p"/users/log_in"} class="hover:text-claude-text">
            Iniciar sesión
          </.link>
        <% end %>
      </div>
    </aside>
    """
  end

  attr :message, :map, required: true

  def message(%{message: %{role: "user"}} = assigns) do
    ~H"""
    <div class="flex justify-end">
      <div class="w-fit max-w-[85%] sm:max-w-[75%] rounded-2xl bg-claude-panel px-3 sm:px-4 py-2.5 text-[15px] leading-7 text-claude-text whitespace-pre-wrap"><%= @message.content %></div>
    </div>
    """
  end

  def message(%{message: %{role: "assistant"}} = assigns) do
    ~H"""
    <div class="flex gap-2 sm:gap-4">
      <div class="mt-1 flex h-6 w-6 sm:h-7 sm:w-7 shrink-0 items-center justify-center rounded-full bg-claude-accent text-white">
        <.icon name="hero-sparkles-solid" class="h-3.5 w-3.5 sm:h-4 sm:w-4" />
      </div>
      <div class="min-w-0 flex-1 markdown-body">
        {Phoenix.HTML.raw(Markdown.to_html(@message.content))}
      </div>
    </div>
    """
  end

  # Unknown role — render plain, safe fallback
  def message(assigns) do
    ~H"""
    <div class="text-sm text-claude-textmuted italic">
      [{@message.role}] {@message.content}
    </div>
    """
  end

  @doc """
  Read-only composer that mirrors Claude's input — textarea + attach / send
  buttons, all permanently disabled.
  """
  def composer_placeholder(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-3xl px-3 sm:px-4 pb-4 sm:pb-6">
      <div
        aria-disabled="true"
        class="flex flex-col gap-2 rounded-2xl border border-claude-border bg-claude-panel/90 p-3 shadow-sm"
      >
        <textarea
          rows="2"
          disabled
          tabindex="-1"
          placeholder="Modo solo lectura — esta conversación está archivada."
          class="w-full resize-none border-0 bg-transparent px-2 py-1.5 text-[15px] leading-6 text-claude-text placeholder:text-claude-textfaint focus:outline-none focus:ring-0 disabled:cursor-not-allowed"
        ></textarea>

        <div class="flex items-center justify-between gap-2">
          <div class="flex items-center gap-1">
            <button
              type="button"
              disabled
              tabindex="-1"
              title="Adjuntar archivo (deshabilitado)"
              class="flex h-8 w-8 items-center justify-center rounded-lg text-claude-textmuted hover:bg-claude-hover/60 disabled:cursor-not-allowed disabled:opacity-60 disabled:hover:bg-transparent"
            >
              <.icon name="hero-paper-clip" class="h-5 w-5" />
            </button>
            <button
              type="button"
              disabled
              tabindex="-1"
              title="Herramientas (deshabilitado)"
              class="flex h-8 items-center gap-1.5 rounded-lg px-2 text-sm text-claude-textmuted hover:bg-claude-hover/60 disabled:cursor-not-allowed disabled:opacity-60 disabled:hover:bg-transparent"
            >
              <.icon name="hero-adjustments-horizontal" class="h-4 w-4" />
              <span>Herramientas</span>
            </button>
          </div>

          <div class="flex items-center gap-2">
            <span class="flex items-center gap-1 text-xs text-claude-textfaint">
              <.icon name="hero-lock-closed-mini" class="h-3.5 w-3.5" />
              Solo lectura
            </span>
            <button
              type="button"
              disabled
              tabindex="-1"
              title="Enviar (deshabilitado)"
              class="flex h-8 w-8 items-center justify-center rounded-lg bg-claude-accent text-white opacity-60 disabled:cursor-not-allowed"
            >
              <.icon name="hero-arrow-up" class="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

end
