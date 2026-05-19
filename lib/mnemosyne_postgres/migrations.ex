defmodule MnemosynePostgres.Migrations do
  @current_version 1

  @moduledoc """
  Migrations for the MnemosynePostgres tables and indexes.

  ## Usage

  Create a migration in your application:

      defmodule MyApp.Repo.Migrations.AddMnemosyne do
        use Ecto.Migration

        def up, do: MnemosynePostgres.Migrations.up(version: 1, embedding_dimensions: 1536)
        def down, do: MnemosynePostgres.Migrations.down(version: 1)
      end

  When a new version is released, generate a new migration:

      defmodule MyApp.Repo.Migrations.UpgradeMnemosyneV2 do
        use Ecto.Migration

        def up, do: MnemosynePostgres.Migrations.up(version: 2, embedding_dimensions: 1536)
        def down, do: MnemosynePostgres.Migrations.down(version: 2)
      end

  ## Options

    * `:version` - the target migration version (defaults to `#{@current_version}`)
    * `:embedding_dimensions` - (required for V1) the dimensionality of your embedding vectors
    * `:index_type` - `:hnsw` (default) or `:ivfflat`
    * `:hnsw_m` - max number of connections per layer for HNSW
    * `:hnsw_ef_construction` - size of the dynamic candidate list for HNSW
    * `:ivfflat_lists` - number of inverted lists for IVFFlat
    * `:prefix` - table name prefix, defaults to `"mnemosyne_"`
  """
  use Ecto.Migration

  @version_modules %{
    1 => MnemosynePostgres.Migrations.V1
  }

  @doc """
  Returns the current migration version.
  """
  @spec current_version() :: pos_integer()
  def current_version, do: @current_version

  @doc """
  Runs the `up` migration for the given version.

  Executes all migration versions from the currently migrated version
  up to the target version sequentially.
  """
  @spec up(keyword()) :: :ok
  def up(opts \\ []) do
    version = Keyword.get(opts, :version, @current_version)
    prefix = Keyword.get(opts, :prefix, "mnemosyne_")

    initial = migrated_version(repo(), prefix)

    Enum.each((initial + 1)..version//1, fn vsn ->
      module = Map.fetch!(@version_modules, vsn)
      module.up(opts)
    end)

    set_version(prefix, version)
  end

  @doc """
  Runs the `down` migration for the given version.

  Rolls back from the currently migrated version down to the target version.
  When called with `version: 1`, it rolls back V1 (dropping all tables).
  """
  @spec down(keyword()) :: :ok
  def down(opts \\ []) do
    version = Keyword.get(opts, :version, @current_version)
    prefix = Keyword.get(opts, :prefix, "mnemosyne_")

    current = migrated_version(repo(), prefix)

    Enum.each(current..version//-1, fn vsn ->
      module = Map.fetch!(@version_modules, vsn)
      module.down(opts)
    end)

    :ok
  end

  @doc """
  Returns the version that has been migrated, based on the table comment.
  Returns 0 if no migrations have run.
  """
  @spec migrated_version(Ecto.Repo.t(), String.t()) :: non_neg_integer()
  def migrated_version(repo, prefix \\ "mnemosyne_") do
    table_name = "#{prefix}nodes"

    query = "SELECT obj_description(oid) FROM pg_class WHERE relname = '#{table_name}'"

    case repo.query(query) do
      {:ok, %{rows: [[comment]]}} when is_binary(comment) ->
        String.to_integer(comment)

      _ ->
        0
    end
  end

  defp set_version(prefix, version) do
    table_name = "#{prefix}nodes"
    execute "COMMENT ON TABLE #{table_name} IS '#{version}'"
  end
end
