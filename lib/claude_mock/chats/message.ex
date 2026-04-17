defmodule ClaudeMock.Chats.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias ClaudeMock.Chats.Conversation

  @roles ~w(user assistant)

  @foreign_key_type :binary_id

  schema "messages" do
    field :role, :string
    field :content, :string
    field :position, :integer

    belongs_to :conversation, Conversation

    timestamps(type: :utc_datetime)
  end

  def roles, do: @roles

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :position, :conversation_id])
    |> validate_required([:role, :content, :position])
    |> validate_inclusion(:role, @roles)
  end
end
