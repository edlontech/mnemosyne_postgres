defmodule MnemosynePostgres.Backend do
  @moduledoc """
  PostgreSQL/pgvector implementation of `Mnemosyne.GraphBackend`.

  Persists knowledge graph nodes in a single polymorphic `nodes` table
  with JSONB data, vector embeddings, and JSONB link maps. Metadata
  is stored in a separate `node_metadata` table.
  """

  @behaviour Mnemosyne.GraphBackend

  import Ecto.Query

  alias Mnemosyne.Errors.Framework.StorageError
  alias Mnemosyne.Graph.Node, as: NodeProtocol
  alias Mnemosyne.Graph.Similarity
  alias Mnemosyne.NodeMetadata
  alias MnemosynePostgres.NodeSerializer
  alias MnemosynePostgres.Queries.MetadataQueries
  alias MnemosynePostgres.Queries.NodeQueries

  @required_opts [:repo, :tenant_id, :repo_id]

  @impl true
  def init(opts) do
    with :ok <- validate_opts(opts) do
      {:ok,
       %{
         repo: opts[:repo],
         tenant_id: opts[:tenant_id],
         repo_id: opts[:repo_id],
         prefix: Keyword.get(opts, :prefix, "mnemosyne_")
       }}
    end
  end

  @impl true
  def apply_changeset(changeset, state) do
    state.repo.transaction(fn ->
      insert_nodes(changeset.additions, state)
      apply_links(changeset.links, state)
      upsert_metadata(changeset.metadata, state)
    end)
    |> case do
      {:ok, _} -> {:ok, state}
      {:error, reason} -> {:error, storage_error(:apply_changeset, reason)}
    end
  end

  @impl true
  def delete_nodes(node_ids, state) when is_list(node_ids) do
    state.repo.transaction(fn ->
      clean_stale_links(node_ids, state)
      delete_metadata_for_ids(node_ids, state)
      delete_nodes_by_ids(node_ids, state)
    end)
    |> case do
      {:ok, _} -> {:ok, state}
      {:error, reason} -> {:error, storage_error(:delete_nodes, reason)}
    end
  end

  @impl true
  def find_candidates(node_types, query_embedding, tag_embeddings, vf_config, _opts, state) do
    vf_module = Map.get(vf_config, :module, Mnemosyne.ValueFunction.Default)
    pgvector_query = Pgvector.new(query_embedding)

    try do
      rows_by_type =
        Enum.map(node_types, fn type ->
          params = get_in(vf_config, [:params, type]) || %{}
          top_k = Map.get(params, :top_k, 20)
          limit = top_k * 2

          rows =
            NodeQueries.vector_search(state, type, pgvector_query, limit) |> state.repo.all()

          {type, rows}
        end)

      all_node_ids =
        rows_by_type
        |> Enum.flat_map(fn {_type, rows} -> Enum.map(rows, & &1.id) end)
        |> Enum.uniq()

      metadata_map = fetch_metadata_map(all_node_ids, state)

      candidates =
        Enum.flat_map(rows_by_type, fn {type, rows} ->
          params = get_in(vf_config, [:params, type]) || %{}
          threshold = Map.get(params, :threshold, 0.0)
          top_k = Map.get(params, :top_k, 20)

          rows
          |> Enum.map(fn row ->
            node = NodeSerializer.from_row(row)
            emb = NodeProtocol.embedding(node)
            relevance = compute_relevance(emb, query_embedding, tag_embeddings)
            node_meta = Map.get(metadata_map, node.id)
            score = vf_module.score(relevance, node, node_meta, params)
            {node, score}
          end)
          |> Enum.filter(fn {_node, score} -> score >= threshold end)
          |> Enum.sort_by(&elem(&1, 1), :desc)
          |> Enum.take(top_k)
        end)

      deduped =
        Enum.uniq_by(candidates, fn {node, _score} -> NodeProtocol.id(node) end)

      {:ok, deduped, state}
    rescue
      e -> {:error, storage_error(:find_candidates, e)}
    end
  end

  @impl true
  def get_node(id, state) do
    row =
      state
      |> NodeQueries.base()
      |> NodeQueries.by_ids([id])
      |> state.repo.one()

    node = if row, do: NodeSerializer.from_row(row)
    {:ok, node, state}
  end

  @impl true
  def get_linked_nodes(node_ids, _edge_type, state) do
    unique_ids = Enum.uniq(node_ids)

    nodes =
      state
      |> NodeQueries.base()
      |> NodeQueries.by_ids(unique_ids)
      |> state.repo.all()
      |> Enum.map(&NodeSerializer.from_row/1)
      |> Enum.uniq_by(&NodeProtocol.id/1)

    {:ok, nodes, state}
  end

  @impl true
  def get_nodes_by_type(node_types, state) do
    try do
      nodes =
        state
        |> NodeQueries.scoped()
        |> NodeQueries.by_types(node_types)
        |> state.repo.all()
        |> Enum.map(&NodeSerializer.from_row/1)

      {:ok, nodes, state}
    rescue
      e -> {:error, storage_error(:get_nodes_by_type, e)}
    end
  end

  @impl true
  def get_metadata(node_ids, state) do
    rows =
      state
      |> MetadataQueries.base()
      |> MetadataQueries.by_node_ids(node_ids)
      |> state.repo.all()

    result = Map.new(rows, fn row -> {row.node_id, row_to_node_metadata(row)} end)
    {:ok, result, state}
  end

  @impl true
  def update_metadata(entries, state) when map_size(entries) == 0, do: {:ok, state}

  def update_metadata(entries, state) do
    now = DateTime.utc_now()
    source = MetadataQueries.source(state)

    rows =
      Enum.map(entries, fn {node_id, %NodeMetadata{} = meta} ->
        %{
          tenant_id: state.tenant_id,
          node_id: node_id,
          access_count: meta.access_count,
          last_accessed_at: meta.last_accessed_at,
          created_at: meta.created_at || now,
          cumulative_reward: meta.cumulative_reward,
          reward_count: meta.reward_count
        }
      end)

    replace_fields = [
      :access_count,
      :last_accessed_at,
      :cumulative_reward,
      :reward_count
    ]

    state.repo.insert_all(source, rows,
      on_conflict: {:replace, replace_fields},
      conflict_target: [:tenant_id, :node_id]
    )

    {:ok, state}
  end

  @impl true
  def delete_metadata(node_ids, state) do
    state
    |> MetadataQueries.base()
    |> MetadataQueries.by_node_ids(node_ids)
    |> state.repo.delete_all()

    {:ok, state}
  end

  # -- Private helpers --

  defp validate_opts(opts) do
    missing = Enum.reject(@required_opts, &Keyword.has_key?(opts, &1))

    case missing do
      [] -> :ok
      keys -> {:error, storage_error(:init, "missing required options: #{inspect(keys)}")}
    end
  end

  defp insert_nodes([], _state), do: :ok

  defp insert_nodes(additions, state) do
    rows = Enum.map(additions, &NodeSerializer.to_row(&1, state.tenant_id, state.repo_id))
    source = NodeQueries.source(state)
    state.repo.insert_all(source, rows)
  end

  defp apply_links([], _state), do: :ok

  defp apply_links(links, state) do
    link_map = build_link_map(links)
    affected_ids = Map.keys(link_map)

    current_links_by_id =
      state
      |> NodeQueries.base()
      |> NodeQueries.by_ids(affected_ids)
      |> select([n], {n.id, n.links})
      |> state.repo.all()
      |> Map.new()

    source = NodeQueries.source(state)

    Enum.each(link_map, fn {node_id, new_links} ->
      current = Map.get(current_links_by_id, node_id, Mnemosyne.Graph.Edge.empty_links())
      merged = merge_links(current, new_links)

      from(n in source, where: n.id == ^node_id and n.tenant_id == ^state.tenant_id)
      |> state.repo.update_all(set: [links: merged])
    end)
  end

  defp build_link_map(links) do
    Enum.reduce(links, %{}, fn {id_a, id_b, edge_type}, acc ->
      acc
      |> Map.update(id_a, %{edge_type => MapSet.new([id_b])}, fn existing ->
        Map.update(existing, edge_type, MapSet.new([id_b]), &MapSet.put(&1, id_b))
      end)
      |> Map.update(id_b, %{edge_type => MapSet.new([id_a])}, fn existing ->
        Map.update(existing, edge_type, MapSet.new([id_a]), &MapSet.put(&1, id_a))
      end)
    end)
  end

  defp merge_links(current_links, new_links) do
    Enum.reduce(new_links, current_links, fn {edge_type, id_set}, acc ->
      existing = Map.get(acc, edge_type, MapSet.new())
      Map.put(acc, edge_type, MapSet.union(existing, id_set))
    end)
  end

  defp clean_stale_links(deleted_ids, state) do
    deleted_set = MapSet.new(deleted_ids)
    source = NodeQueries.source(state)

    rows =
      state
      |> NodeQueries.scoped()
      |> where([n], n.id not in ^deleted_ids)
      |> select([n], {n.id, n.links})
      |> state.repo.all()

    Enum.each(rows, fn {node_id, links} ->
      cleaned =
        Map.new(links, fn {edge_type, id_set} ->
          {edge_type, MapSet.difference(id_set, deleted_set)}
        end)

      if cleaned != links do
        from(n in source, where: n.id == ^node_id and n.tenant_id == ^state.tenant_id)
        |> state.repo.update_all(set: [links: cleaned])
      end
    end)
  end

  defp delete_metadata_for_ids(node_ids, state) do
    state
    |> MetadataQueries.base()
    |> MetadataQueries.by_node_ids(node_ids)
    |> state.repo.delete_all()
  end

  defp delete_nodes_by_ids(node_ids, state) do
    state
    |> NodeQueries.base()
    |> NodeQueries.by_ids(node_ids)
    |> state.repo.delete_all()
  end

  defp upsert_metadata(metadata, _state) when map_size(metadata) == 0, do: :ok

  defp upsert_metadata(metadata, state) do
    now = DateTime.utc_now()
    source = MetadataQueries.source(state)

    rows =
      Enum.map(metadata, fn {node_id, %NodeMetadata{} = meta} ->
        %{
          tenant_id: state.tenant_id,
          node_id: node_id,
          access_count: meta.access_count,
          last_accessed_at: meta.last_accessed_at,
          created_at: meta.created_at || now,
          cumulative_reward: meta.cumulative_reward,
          reward_count: meta.reward_count
        }
      end)

    replace_fields = [
      :access_count,
      :last_accessed_at,
      :cumulative_reward,
      :reward_count
    ]

    state.repo.insert_all(source, rows,
      on_conflict: {:replace, replace_fields},
      conflict_target: [:tenant_id, :node_id]
    )
  end

  defp fetch_metadata_map([], _state), do: %{}

  defp fetch_metadata_map(node_ids, state) do
    rows =
      state
      |> MetadataQueries.base()
      |> MetadataQueries.by_node_ids(node_ids)
      |> state.repo.all()

    Map.new(rows, fn row -> {row.node_id, row_to_node_metadata(row)} end)
  end

  defp compute_relevance(nil, _query_embedding, _tag_embeddings), do: 0.0

  defp compute_relevance(emb, query_embedding, tag_embeddings) do
    query_sim = Similarity.cosine_similarity(query_embedding, emb)

    tag_sim =
      tag_embeddings
      |> Enum.map(&Similarity.cosine_similarity(&1, emb))
      |> Enum.max(fn -> 0.0 end)

    max(query_sim, tag_sim) |> max(0.0)
  end

  defp row_to_node_metadata(row) do
    %NodeMetadata{
      access_count: row.access_count,
      last_accessed_at: row.last_accessed_at,
      created_at: row.created_at,
      cumulative_reward: row.cumulative_reward,
      reward_count: row.reward_count
    }
  end

  defp storage_error(operation, reason) do
    %StorageError{operation: operation, reason: reason}
  end
end
