defmodule MnemosynePostgres.Queries.NodeQueriesTest do
  use MnemosynePostgres.DataCase, async: true

  alias MnemosynePostgres.Queries.NodeQueries

  @state %{tenant_id: "t1", repo_id: "r1", prefix: "mnemosyne_"}

  setup do
    insert(:node,
      id: "n1",
      type: "semantic",
      data: %{"proposition" => "test", "confidence" => 0.9},
      embedding: Pgvector.new([0.1, 0.2, 0.3])
    )

    insert(:node,
      id: "n2",
      type: "episodic",
      data: %{
        "observation" => "obs",
        "action" => "act",
        "state" => "s",
        "subgoal" => "sg",
        "reward" => 1.0,
        "trajectory_id" => "tr1"
      },
      embedding: Pgvector.new([0.4, 0.5, 0.6])
    )

    insert(:node,
      id: "n3",
      tenant_id: "t2",
      type: "semantic",
      data: %{"proposition" => "other tenant", "confidence" => 0.5},
      embedding: Pgvector.new([0.7, 0.8, 0.9])
    )

    :ok
  end

  describe "scoped/1" do
    test "returns only nodes matching tenant_id and repo_id" do
      results = @state |> NodeQueries.scoped() |> Repo.all()

      assert length(results) == 2
      assert Enum.all?(results, &(&1.tenant_id == "t1"))
      assert Enum.all?(results, &(&1.repo_id == "r1"))
    end

    test "excludes nodes from other tenants" do
      ids = @state |> NodeQueries.scoped() |> Repo.all() |> Enum.map(& &1.id)

      refute "n3" in ids
    end
  end

  describe "by_types/2" do
    test "filters nodes by type" do
      results =
        @state
        |> NodeQueries.scoped()
        |> NodeQueries.by_types([:semantic])
        |> Repo.all()

      assert [%{id: "n1", type: "semantic"}] = results
    end

    test "returns multiple types when requested" do
      results =
        @state
        |> NodeQueries.scoped()
        |> NodeQueries.by_types([:semantic, :episodic])
        |> Repo.all()

      assert length(results) == 2
    end
  end

  describe "by_ids/2" do
    test "filters nodes by specific IDs" do
      results =
        @state
        |> NodeQueries.scoped()
        |> NodeQueries.by_ids(["n1"])
        |> Repo.all()

      assert [%{id: "n1"}] = results
    end

    test "returns multiple nodes for multiple IDs" do
      results =
        @state
        |> NodeQueries.scoped()
        |> NodeQueries.by_ids(["n1", "n2"])
        |> Repo.all()

      assert length(results) == 2
    end

    test "ignores IDs not in scope" do
      results =
        @state
        |> NodeQueries.scoped()
        |> NodeQueries.by_ids(["n3"])
        |> Repo.all()

      assert results == []
    end
  end

  describe "vector_search/4" do
    test "returns nodes ordered by cosine distance" do
      query_embedding = Pgvector.new([0.1, 0.2, 0.3])
      results = NodeQueries.vector_search(@state, :semantic, query_embedding, 10) |> Repo.all()

      assert [%{id: "n1"}] = results
    end

    test "populates the virtual distance field" do
      query_embedding = Pgvector.new([0.1, 0.2, 0.3])
      results = NodeQueries.vector_search(@state, :semantic, query_embedding, 10) |> Repo.all()

      assert [%{distance: distance}] = results
      assert is_float(distance)
      assert distance >= 0.0
    end

    test "respects the limit parameter" do
      query_embedding = Pgvector.new([0.1, 0.2, 0.3])
      results = NodeQueries.vector_search(@state, :episodic, query_embedding, 1) |> Repo.all()

      assert length(results) <= 1
    end

    test "filters by type" do
      query_embedding = Pgvector.new([0.4, 0.5, 0.6])

      semantic_results =
        NodeQueries.vector_search(@state, :semantic, query_embedding, 10) |> Repo.all()

      episodic_results =
        NodeQueries.vector_search(@state, :episodic, query_embedding, 10) |> Repo.all()

      assert Enum.all?(semantic_results, &(&1.type == "semantic"))
      assert Enum.all?(episodic_results, &(&1.type == "episodic"))
    end
  end
end
