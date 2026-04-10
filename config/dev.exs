import Config

config :mnemosyne_postgres, MnemosynePostgres.Repo,
  username: "postgres",
  password: "postgres",
  database: "mnemosyne_dev",
  hostname: "localhost",
  pool_size: 30
