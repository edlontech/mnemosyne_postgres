defmodule MnemosynePostgres.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: MnemosynePostgres.Repo

  alias MnemosynePostgres.Schema.Node
  alias MnemosynePostgres.Schema.NodeMetadata

  def node_factory do
    %Node{
      id: sequence("node-id", &"node-#{&1}"),
      tenant_id: "t1",
      repo_id: "r1",
      type: "semantic",
      data: %{"proposition" => "test fact", "confidence" => 0.9},
      embedding: Pgvector.new([0.1, 0.2, 0.3]),
      links: %{},
      created_at: DateTime.utc_now()
    }
  end

  def node_metadata_factory do
    %NodeMetadata{
      tenant_id: "t1",
      node_id: sequence("meta-node-id", &"node-#{&1}"),
      access_count: 0,
      last_accessed_at: nil,
      created_at: DateTime.utc_now(),
      cumulative_reward: 0.0,
      reward_count: 0
    }
  end
end
