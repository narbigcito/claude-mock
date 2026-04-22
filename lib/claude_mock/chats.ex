defmodule ClaudeMock.Chats do
  @moduledoc """
  Context for read-only conversation browsing.

  Conversations are seeded from JSON files or inserted/edited via the admin panel.
  The public-facing UI never writes messages.
  """

  import Ecto.Query, warn: false

  alias ClaudeMock.Repo
  alias ClaudeMock.Chats.{Conversation, Message}
  alias Ecto.Multi

  def list_conversations do
    Conversation
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
    |> Enum.sort_by(fn c ->
      if c.title == "Bienvenida a Claude Mock", do: 0, else: 1
    end)
  end

  @doc "Returns conversations plus their message count, newest first."
  def list_conversations_with_counts do
    from(c in Conversation,
      left_join: m in assoc(c, :messages),
      group_by: c.id,
      order_by: [desc: c.updated_at],
      select: %{conversation: c, message_count: count(m.id)}
    )
    |> Repo.all()
  end

  def delete_conversation(%Conversation{} = conversation) do
    Repo.delete(conversation)
  end

  def get_conversation!(id) do
    Conversation
    |> Repo.get!(id)
    |> Repo.preload(messages: from(m in Message, order_by: [asc: m.position]))
  end

  def create_conversation(attrs) do
    %Conversation{}
    |> Conversation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Imports a conversation from a parsed JSON map:

      %{
        "title" => "Something",
        "model" => "claude-opus-4-6",
        "messages" => [
          %{"role" => "user",      "content" => "...", "position" => 0},
          %{"role" => "assistant", "content" => "...", "position" => 1}
        ]
      }

  `position` is optional — if absent, the list index is used. When present it
  wins, which protects against accidental reordering of the `messages` array.
  """
  def import_conversation(%{"title" => title} = payload) do
    create_conversation(%{
      "title" => title,
      "model" => Map.get(payload, "model"),
      "messages" => normalize_messages(Map.get(payload, "messages", []))
    })
  end

  @doc """
  Replaces the title, model, and the entire message list of an existing
  conversation in a single transaction. Preserves the conversation id/URL.
  """
  def update_conversation(%Conversation{} = conversation, payload) do
    title = Map.get(payload, "title", conversation.title)
    model = Map.get(payload, "model", conversation.model)
    messages = normalize_messages(Map.get(payload, "messages", []))

    Multi.new()
    |> Multi.update(
      :conversation,
      Ecto.Changeset.change(conversation, %{title: title, model: model})
    )
    |> Multi.delete_all(:messages, from(m in Message, where: m.conversation_id == ^conversation.id))
    |> Multi.insert_all(
      :inserted,
      Message,
      fn _ ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        Enum.map(messages, fn m ->
          %{
            conversation_id: conversation.id,
            role: m.role,
            content: m.content,
            position: m.position,
            inserted_at: now,
            updated_at: now
          }
        end)
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{conversation: conv}} -> {:ok, get_conversation!(conv.id)}
      {:error, _step, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Serializes a conversation to the JSON payload shape, useful for the admin
  edit form.
  """
  def to_payload(%Conversation{} = conv) do
    %{
      "title" => conv.title,
      "model" => conv.model,
      "messages" =>
        conv.messages
        |> Enum.sort_by(& &1.position)
        |> Enum.map(fn m ->
          %{"role" => m.role, "content" => m.content, "position" => m.position}
        end)
    }
  end

  # -- internal --

  defp normalize_messages(list) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.map(fn {msg, idx} ->
      %{
        role: msg["role"],
        content: msg["content"],
        position: coerce_position(msg["position"], idx)
      }
    end)
  end

  defp normalize_messages(_), do: []

  defp coerce_position(nil, fallback), do: fallback
  defp coerce_position(n, _fallback) when is_integer(n), do: n

  defp coerce_position(s, fallback) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} -> n
      _ -> fallback
    end
  end

  defp coerce_position(_, fallback), do: fallback
end
