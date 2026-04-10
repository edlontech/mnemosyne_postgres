ExUnit.start(exclude: [:integration], capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(MnemosynePostgres.Repo, :manual)
