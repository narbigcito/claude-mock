import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
# Use DATABASE_URL if available (for CI/Docker), otherwise use defaults
if System.get_env("DATABASE_URL") do
  config :claude_mock, ClaudeMock.Repo,
    url: System.get_env("DATABASE_URL"),
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
else
  config :claude_mock, ClaudeMock.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "claude_mock_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
end

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :claude_mock, ClaudeMockWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "qvnVgIp6f6oLRTvQXyIzUEbcs7LKKWquxv23RwXve0WDCFkuls2CN9bVHa6LRf+/",
  server: false

# In test we don't send emails
config :claude_mock, ClaudeMock.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
