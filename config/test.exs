import Config

config :mnemosyne_postgres, MnemosynePostgres.Repo,
  username: "postgres",
  password: "postgres",
  database: "mnemosyne_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 30
