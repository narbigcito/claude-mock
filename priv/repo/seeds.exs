# Seeds the DB by importing every JSON conversation under priv/conversations/.
#
# Run with:
#
#     mix run priv/repo/seeds.exs
#
# Each JSON file must follow this format:
#
#     {
#       "title":   "Something",
#       "model":   "claude-opus-4-6",
#       "messages": [
#         {"position": 0, "role": "user",      "content": "Hi"},
#         {"position": 1, "role": "assistant", "content": "Hello, how can I help?"}
#       ]
#     }
#
# `position` is optional — when omitted, the list index is used. Provide it
# explicitly whenever you want to be certain the order is locked in, independent
# of how the JSON array happens to be serialized.
#
# Existing conversations with the same title are skipped — so re-running
# the seed is safe.

alias ClaudeMock.Chats
alias ClaudeMock.Chats.Conversation
alias ClaudeMock.Repo

import Ecto.Query

dir =
  System.get_env("CONVERSATIONS_DIR") ||
    Path.join([:code.priv_dir(:claude_mock), "conversations"])

files =
  case File.ls(dir) do
    {:ok, entries} -> entries |> Enum.filter(&String.ends_with?(&1, ".json")) |> Enum.sort()
    {:error, _} -> []
  end

if files == [] do
  IO.puts("[seed] no conversations found in #{dir}")
end

Enum.each(files, fn name ->
  path = Path.join(dir, name)
  payload = path |> File.read!() |> Jason.decode!()
  title = payload["title"] || Path.rootname(name)

  if Repo.exists?(from c in Conversation, where: c.title == ^title) do
    IO.puts("[seed] skip #{name} — already imported")
  else
    case Chats.import_conversation(Map.put(payload, "title", title)) do
      {:ok, conv} ->
        IO.puts("[seed] imported #{name} → conversation ##{conv.id}")

      {:error, changeset} ->
        IO.puts("[seed] failed #{name}: #{inspect(changeset.errors)}")
    end
  end
end)
