defmodule ClaudeMockWeb.AdminLive.AdminUsersLive do
  use ClaudeMockWeb, :live_view

  alias ClaudeMock.Accounts
  alias ClaudeMock.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})
    password_changeset = Accounts.change_user_password(%User{})

    {:ok,
     socket
     |> assign(:page_title, "Gestionar Administradores")
     |> assign(:form, to_form(changeset))
     |> assign(:password_form, to_form(password_changeset))
     |> assign(:admins, list_admins())
     |> assign(:trigger_submit, false)
     |> assign(:editing_user, nil)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_admin(user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Admin #{user.email} creado correctamente.")
         |> assign(:form, to_form(Accounts.change_user_registration(%User{})))
         |> assign(:admins, list_admins())}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("promote", %{"email" => email}, socket) do
    case Accounts.promote_to_admin(email) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{user.email} ahora es administrador.")
         |> assign(:admins, list_admins())}

      :not_found ->
        {:noreply,
         socket
         |> put_flash(:error, "Usuario con email #{email} no encontrado.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    # Prevent deleting yourself
    if user.id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> put_flash(:error, "No puedes eliminar tu propia cuenta.")}
    else
      case Accounts.delete_user(user) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Administrador #{user.email} eliminado correctamente.")
           |> assign(:admins, list_admins())}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "No se pudo eliminar el administrador.")}
      end
    end
  end

  @impl true
  def handle_event("edit_password", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    password_changeset = Accounts.change_user_password(user)

    {:noreply,
     socket
     |> assign(:editing_user, user)
     |> assign(:password_form, to_form(password_changeset))}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_user, nil)
     |> assign(:password_form, to_form(Accounts.change_user_password(%User{})))}
  end

  @impl true
  def handle_event("validate_password", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.editing_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, password_form: to_form(changeset))}
  end

  @impl true
  def handle_event("update_password", %{"user" => user_params}, socket) do
    user = socket.assigns.editing_user

    case Accounts.update_admin_password(user, user_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contraseña de #{updated_user.email} actualizada correctamente.")
         |> assign(:editing_user, nil)
         |> assign(:password_form, to_form(Accounts.change_user_password(%User{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  defp list_admins do
    import Ecto.Query
    alias ClaudeMock.Repo

    from(u in User, where: u.is_admin == true, order_by: [desc: u.inserted_at])
    |> Repo.all()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen w-screen overflow-hidden bg-claude-bg text-claude-text">
      <aside class="flex w-64 flex-col border-r border-claude-border bg-claude-panel">
        <div class="flex h-14 items-center border-b border-claude-border px-4">
          <.link navigate={~p"/admin"} class="text-sm font-medium hover:underline">
            ← Volver al Admin
          </.link>
        </div>
      </aside>

      <main class="flex min-w-0 flex-1 flex-col overflow-y-auto">
        <header class="flex h-14 items-center border-b border-claude-border px-6">
          <h1 class="text-[15px] font-medium">Gestionar Administradores</h1>
        </header>

        <div class="mx-auto w-full max-w-2xl px-6 py-8">
          <%!-- Formulario para crear nuevo admin --%>
          <div class="mb-8 rounded-lg border border-claude-border bg-claude-panel/50 p-6">
            <h2 class="mb-4 text-sm font-semibold text-claude-text">Crear nuevo administrador</h2>
            <.form
              for={@form}
              id="admin_form"
              phx-submit="save"
              phx-change="validate"
              class="space-y-4"
            >
              <div>
                <.label for="email">Correo electrónico</.label>
                <.input
                  field={@form[:email]}
                  type="email"
                  placeholder="admin@ejemplo.com"
                  required
                  class="mt-1 w-full rounded border border-claude-border bg-claude-bg px-3 py-2 text-sm text-claude-text"
                />
                <.error :for={error <- @form[:email].errors}>{error}</.error>
              </div>

              <div>
                <.label for="password">Contraseña</.label>
                <.input
                  field={@form[:password]}
                  type="password"
                  placeholder="Mínimo 12 caracteres"
                  required
                  class="mt-1 w-full rounded border border-claude-border bg-claude-bg px-3 py-2 text-sm text-claude-text"
                />
                <.error :for={error <- @form[:password].errors}>{error}</.error>
                <p class="mt-1 text-xs text-claude-textmuted">
                  Mínimo 12 caracteres
                </p>
              </div>

              <div class="pt-2">
                <.button
                  phx-disable-with="Creando..."
                  class="flex items-center gap-2 rounded-lg bg-claude-accent px-4 py-2 text-sm font-medium text-white hover:bg-claude-accenthover disabled:opacity-50"
                >
                  <.icon name="hero-user-plus" class="h-4 w-4" /> Crear administrador
                </.button>
              </div>
            </.form>
          </div>

          <%!-- Lista de admins existentes --%>
          <div class="rounded-lg border border-claude-border">
            <div class="border-b border-claude-border bg-claude-panel px-4 py-3">
              <h2 class="text-sm font-semibold text-claude-text">
                Administradores existentes ({length(@admins)})
              </h2>
            </div>
            <%= if @admins == [] do %>
              <div class="p-6 text-center text-sm text-claude-textmuted">
                No hay administradores registrados.
              </div>
            <% else %>
              <ul class="divide-y divide-claude-border">
                <li :for={admin <- @admins} class="flex items-center justify-between px-4 py-3">
                  <div>
                    <p class="text-sm font-medium text-claude-text">{admin.email}</p>
                    <p class="text-xs text-claude-textmuted">
                      Creado el {Calendar.strftime(admin.inserted_at, "%Y-%m-%d %H:%M")}
                    </p>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class="rounded-full bg-claude-accent/10 px-2 py-1 text-xs font-medium text-claude-accent">
                      Admin
                    </span>
                    <.button
                      phx-click="edit_password"
                      phx-value-id={admin.id}
                      class="rounded p-1.5 text-claude-textmuted hover:bg-claude-border hover:text-claude-accent"
                      title="Cambiar contraseña"
                    >
                      <.icon name="hero-key" class="h-4 w-4" />
                    </.button>
                    <.button
                      :if={admin.id != @current_user.id}
                      phx-click="delete"
                      phx-value-id={admin.id}
                      data-confirm="¿Estás seguro de que quieres eliminar este administrador?"
                      class="rounded p-1.5 text-claude-textmuted hover:bg-claude-border hover:text-red-500"
                      title="Eliminar administrador"
                    >
                      <.icon name="hero-trash" class="h-4 w-4" />
                    </.button>
                  </div>
                </li>
              </ul>
            <% end %>
          </div>

          <%!-- Modal para cambiar contraseña --%>
          <%= if @editing_user do %>
            <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
              <div class="w-full max-w-md rounded-lg border border-claude-border bg-claude-panel p-6 shadow-lg">
                <h3 class="mb-4 text-sm font-semibold text-claude-text">
                  Cambiar contraseña de {@editing_user.email}
                </h3>
                <.form
                  for={@password_form}
                  id="password_form"
                  phx-submit="update_password"
                  phx-change="validate_password"
                  class="space-y-4"
                >
                  <div>
                    <.label for="password">Nueva contraseña</.label>
                    <.input
                      field={@password_form[:password]}
                      type="password"
                      placeholder="Mínimo 12 caracteres"
                      required
                      class="mt-1 w-full rounded border border-claude-border bg-claude-bg px-3 py-2 text-sm text-claude-text"
                    />
                    <.error :for={error <- @password_form[:password].errors}>{error}</.error>
                    <p class="mt-1 text-xs text-claude-textmuted">
                      Mínimo 12 caracteres
                    </p>
                  </div>

                  <div>
                    <.label for="password_confirmation">Confirmar contraseña</.label>
                    <.input
                      field={@password_form[:password_confirmation]}
                      type="password"
                      placeholder="Repite la contraseña"
                      required
                      class="mt-1 w-full rounded border border-claude-border bg-claude-bg px-3 py-2 text-sm text-claude-text"
                    />
                    <.error :for={error <- @password_form[:password_confirmation].errors}>{error}</.error>
                  </div>

                  <div class="flex gap-3 pt-2">
                    <.button
                      type="button"
                      phx-click="cancel_edit"
                      class="flex-1 rounded-lg border border-claude-border px-4 py-2 text-sm font-medium text-claude-text hover:bg-claude-border"
                    >
                      Cancelar
                    </.button>
                    <.button
                      phx-disable-with="Guardando..."
                      class="flex-1 rounded-lg bg-claude-accent px-4 py-2 text-sm font-medium text-white hover:bg-claude-accenthover"
                    >
                      Guardar
                    </.button>
                  </div>
                </.form>
              </div>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end
end
