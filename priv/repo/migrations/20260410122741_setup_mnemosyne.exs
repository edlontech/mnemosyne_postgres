defmodule MnemosynePostgres.Repo.Migrations.SetupMnemosyne do
  use Ecto.Migration

  def up do
    MnemosynePostgres.Migrations.up(version: 1, embedding_dimensions: 3)
  end

  def down do
    MnemosynePostgres.Migrations.down(version: 1)
  end
end
