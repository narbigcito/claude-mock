defmodule ClaudeMock.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :claude_mock

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Imports every JSON conversation under priv/conversations/ into the DB.
  Safe to re-run — conversations with an existing title are skipped.
  """
  def seed_conversations do
    load_app()
    {:ok, _} = Application.ensure_all_started(@app)

    dir =
      System.get_env("CONVERSATIONS_DIR") ||
        Path.join(:code.priv_dir(@app), "conversations")

    files =
      case File.ls(dir) do
        {:ok, entries} -> entries |> Enum.filter(&String.ends_with?(&1, ".json")) |> Enum.sort()
        {:error, _} -> []
      end

    import Ecto.Query
    alias ClaudeMock.{Chats, Repo}
    alias ClaudeMock.Chats.Conversation

    Enum.each(files, fn name ->
      path = Path.join(dir, name)
      payload = path |> File.read!() |> Jason.decode!()
      title = payload["title"] || Path.rootname(name)

      if Repo.exists?(from c in Conversation, where: c.title == ^title) do
        IO.puts("[seed] skip #{name} — already imported")
      else
        case Chats.import_conversation(Map.put(payload, "title", title)) do
          {:ok, conv} -> IO.puts("[seed] imported #{name} → conversation ##{conv.id}")
          {:error, cs} -> IO.puts("[seed] failed #{name}: #{inspect(cs.errors)}")
        end
      end
    end)
  end

  @doc """
  Bootstraps an admin account. Run once after the first deploy:

      bin/claude_mock eval 'ClaudeMock.Release.create_admin("admin@example.com", "super-secret-123")'

  Or using the migrate script (which doesn't start the web server):

      bin/migrate eval 'ClaudeMock.Release.create_admin("admin@example.com", "super-secret-123")'
  """
  def create_admin(email, password) when is_binary(email) and is_binary(password) do
    load_app()

    # Start only required applications, not the full web server
    {:ok, _} = Application.ensure_all_started(:crypto)
    {:ok, _} = Application.ensure_all_started(:ssl)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)

    # Start repos manually
    for repo <- repos() do
      {:ok, _} = repo.start_link(pool_size: 2)
    end

    case ClaudeMock.Accounts.register_admin(%{email: email, password: password}) do
      {:ok, user} ->
        IO.puts("[admin] created #{user.email}")
        {:ok, user}

      {:error, cs} ->
        IO.puts("[admin] failed: #{inspect(cs.errors)}")
        {:error, cs}
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
