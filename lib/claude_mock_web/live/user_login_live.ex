defmodule ClaudeMockWeb.UserLoginLive do
  use ClaudeMockWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen items-center justify-center bg-claude-bg px-4">
      <div class="w-full max-w-sm rounded-2xl border border-claude-border bg-claude-sidebar p-8 shadow-lg">
        <div class="mb-6 flex items-center justify-center gap-2">
          <div class="flex h-8 w-8 items-center justify-center rounded-md bg-claude-accent text-white">
            <.icon name="hero-sparkles-solid" class="h-4 w-4" />
          </div>
          <span class="font-serif text-xl text-claude-text">Claude</span>
        </div>

        <.header class="text-center">
          Inicia sesión
          <:subtitle>
            Acceso restringido a administradores.
          </:subtitle>
        </.header>

        <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Contraseña" required />

          <:actions>
            <.input field={@form[:remember_me]} type="checkbox" label="Mantener sesión iniciada" />
            <.link
              href={~p"/users/reset_password"}
              class="text-sm font-semibold text-claude-textmuted hover:text-claude-text"
            >
              ¿Olvidaste tu contraseña?
            </.link>
          </:actions>
          <:actions>
            <.button phx-disable-with="Ingresando..." class="w-full">
              Ingresar <span aria-hidden="true">→</span>
            </.button>
          </:actions>
        </.simple_form>

        <p class="mt-6 text-center text-xs text-claude-textfaint">
          <.link navigate={~p"/"} class="hover:text-claude-text">← Volver al visor</.link>
        </p>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
