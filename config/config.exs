import Config

if config_env() in [:test, :dev] do
  config :mnemosyne_postgres, ecto_repos: [MnemosynePostgres.Repo]
end

import_config "#{config_env()}.exs"
