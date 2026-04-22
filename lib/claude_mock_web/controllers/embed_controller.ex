defmodule ClaudeMockWeb.EmbedController do
  use ClaudeMockWeb, :controller

  alias ClaudeMock.Chats

  plug :put_root_layout, false
  plug :put_layout, false
  plug :allow_iframe

  def show(conn, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        conversation = Chats.get_conversation!(uuid)

        conn
        |> put_view(ClaudeMockWeb.EmbedHTML)
        |> render(:show, conversation: conversation)

      :error ->
        send_resp(conn, 404, "not found")
    end
  end

  def export(conn, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        conversation = Chats.get_conversation!(uuid)
        filename = String.replace(conversation.title, ~r/[^\w\s-]/, "") <> ".html"

        conn
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> put_view(ClaudeMockWeb.EmbedHTML)
        |> render(:export, conversation: conversation)

      :error ->
        send_resp(conn, 404, "not found")
    end
  end

  defp allow_iframe(conn, _opts) do
    conn
    |> delete_resp_header("x-frame-options")
    |> put_resp_header("content-security-policy", "frame-ancestors *")
  end
end
