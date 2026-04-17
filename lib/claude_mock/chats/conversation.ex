defmodule ClaudeMock.Chats.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias ClaudeMock.Accounts.User
  alias ClaudeMock.Chats.Message

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    field :title, :string
    field :model, :string

    belongs_to :user, User
    has_many :messages, Message, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :model, :user_id])
    |> validate_required([:title])
    |> validate_length(:title, max: 255)
    |> cast_assoc(:messages, with: &Message.changeset/2)
  end
end
