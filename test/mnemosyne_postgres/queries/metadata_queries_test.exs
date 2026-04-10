defmodule MnemosynePostgres.Queries.MetadataQueriesTest do
  use MnemosynePostgres.DataCase, async: true

  alias MnemosynePostgres.Queries.MetadataQueries

  @state %{tenant_id: "t1", repo_id: "r1", prefix: "mnemosyne_"}

  setup do
    insert(:node_metadata, tenant_id: "t1", node_id: "n1", access_count: 5)
    insert(:node_metadata, tenant_id: "t1", node_id: "n2", access_count: 3)
    insert(:node_metadata, tenant_id: "t2", node_id: "n3", access_count: 1)

    :ok
  end

  describe "base/1" do
    test "returns metadata scoped to tenant_id" do
      results = @state |> MetadataQueries.base() |> Repo.all()

      assert length(results) == 2
      assert Enum.all?(results, &(&1.tenant_id == "t1"))
    end

    test "excludes metadata from other tenants" do
      node_ids = @state |> MetadataQueries.base() |> Repo.all() |> Enum.map(& &1.node_id)

      refute "n3" in node_ids
    end
  end

  describe "by_node_ids/2" do
    test "filters metadata by specific node IDs" do
      results =
        @state
        |> MetadataQueries.base()
        |> MetadataQueries.by_node_ids(["n1"])
        |> Repo.all()

      assert [%{node_id: "n1"}] = results
    end

    test "returns multiple entries for multiple node IDs" do
      results =
        @state
        |> MetadataQueries.base()
        |> MetadataQueries.by_node_ids(["n1", "n2"])
        |> Repo.all()

      assert length(results) == 2
    end

    test "returns empty list for non-existent node IDs" do
      results =
        @state
        |> MetadataQueries.base()
        |> MetadataQueries.by_node_ids(["nonexistent"])
        |> Repo.all()

      assert results == []
    end
  end
end
