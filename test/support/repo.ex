defmodule MnemosynePostgres.Repo do
  use Ecto.Repo,
    otp_app: :mnemosyne_postgres,
    adapter: Ecto.Adapters.Postgres
end
