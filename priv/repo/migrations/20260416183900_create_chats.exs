defmodule ClaudeMock.Repo.Migrations.CreateChats do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :model, :string
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:user_id])
    create index(:conversations, [:updated_at])

    create table(:messages) do
      add :conversation_id,
          references(:conversations, on_delete: :delete_all, type: :binary_id),
          null: false

      add :role, :string, null: false
      add :content, :text, null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:conversation_id])
    create unique_index(:messages, [:conversation_id, :position])
  end
end
