defmodule MnemosynePostgres.Repo.Migrations.SetupIntegration do
  use Ecto.Migration

  def up do
    MnemosynePostgres.Migrations.up(
      version: 1,
      embedding_dimensions: 1536,
      prefix: "integration_"
    )
  end

  def down do
    MnemosynePostgres.Migrations.down(version: 1, prefix: "integration_")
  end
end
