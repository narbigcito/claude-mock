defmodule ClaudeMock.Repo do
  use Ecto.Repo,
    otp_app: :claude_mock,
    adapter: Ecto.Adapters.Postgres
end
