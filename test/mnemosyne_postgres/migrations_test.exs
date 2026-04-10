defmodule MnemosynePostgres.MigrationsTest do
  use MnemosynePostgres.DataCase, async: true

  alias MnemosynePostgres.Repo

  @node_types ~w(semantic episodic procedural subgoal source tag intent)

  describe "current_version/0" do
    test "returns the current migration version" do
      assert MnemosynePostgres.Migrations.current_version() >= 1
    end
  end

  describe "migrated_version/2" do
    test "returns the version stored in the table comment" do
      assert MnemosynePostgres.Migrations.migrated_version(Repo) >= 1
    end
  end

  describe "mnemosyne_nodes table" do
    test "has the expected columns" do
      {:ok, %{rows: rows}} =
        Repo.query(
          "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'mnemosyne_nodes' ORDER BY ordinal_position"
        )

      column_map = Map.new(rows, fn [name, type] -> {name, type} end)

      assert column_map["id"] == "text"
      assert column_map["tenant_id"] == "text"
      assert column_map["repo_id"] == "text"
      assert column_map["type"] == "text"
      assert column_map["data"] == "jsonb"
      assert column_map["embedding"] == "USER-DEFINED"
      assert column_map["links"] == "jsonb"
      assert column_map["created_at"] == "timestamp with time zone"
    end
  end

  describe "mnemosyne_node_metadata table" do
    test "has the expected columns" do
      {:ok, %{rows: rows}} =
        Repo.query(
          "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'mnemosyne_node_metadata' ORDER BY ordinal_position"
        )

      column_map = Map.new(rows, fn [name, type] -> {name, type} end)

      assert column_map["tenant_id"] == "text"
      assert column_map["node_id"] == "text"
      assert column_map["access_count"] == "integer"
      assert column_map["last_accessed_at"] == "timestamp with time zone"
      assert column_map["created_at"] == "timestamp with time zone"
      assert column_map["cumulative_reward"] == "double precision"
      assert column_map["reward_count"] == "integer"
    end

    test "has a foreign key on node_id referencing mnemosyne_nodes" do
      {:ok, %{rows: rows}} =
        Repo.query("""
        SELECT tc.constraint_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'mnemosyne_node_metadata'
          AND tc.constraint_type = 'FOREIGN KEY'
          AND kcu.column_name = 'node_id'
        """)

      assert length(rows) == 1
    end
  end

  describe "indexes" do
    test "has a btree index on tenant_id, repo_id, type" do
      {:ok, %{rows: rows}} =
        Repo.query("""
        SELECT indexname FROM pg_indexes
        WHERE tablename = 'mnemosyne_nodes'
        AND indexdef LIKE '%btree%'
        AND indexdef LIKE '%tenant_id%'
        AND indexdef LIKE '%repo_id%'
        AND indexdef LIKE '%type%'
        """)

      assert length(rows) == 1
    end

    test "has a partial HNSW index per node type" do
      for node_type <- @node_types do
        {:ok, %{rows: rows}} =
          Repo.query(
            """
            SELECT indexname FROM pg_indexes
            WHERE tablename = 'mnemosyne_nodes'
            AND indexdef LIKE '%hnsw%'
            AND indexdef LIKE $1
            """,
            ["%type = '#{node_type}'%"]
          )

        assert [_] = rows, "expected one HNSW index for type #{node_type}"
      end
    end
  end
end
