defmodule MnemosynePostgres.Migrations.V1 do
  @moduledoc false
  use Ecto.Migration

  @node_types ~w(semantic episodic procedural subgoal source tag intent)

  def up(opts) do
    prefix = Keyword.get(opts, :prefix, "mnemosyne_")
    dimensions = Keyword.fetch!(opts, :embedding_dimensions)
    nodes_table = :"#{prefix}nodes"
    metadata_table = :"#{prefix}node_metadata"

    execute("CREATE EXTENSION IF NOT EXISTS vector")

    create table(nodes_table, primary_key: false) do
      add(:id, :text, primary_key: true, null: false)
      add(:tenant_id, :text, null: false)
      add(:repo_id, :text, null: false)
      add(:type, :text, null: false)
      add(:data, :jsonb, null: false, default: "{}")
      add(:embedding, :"vector(#{dimensions})")
      add(:links, :jsonb, null: false, default: "{}")
      add(:created_at, :timestamptz, null: false)
    end

    create table(metadata_table, primary_key: false) do
      add(:tenant_id, :text, null: false, primary_key: true)

      add(
        :node_id,
        references(nodes_table, type: :text, column: :id, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      add(:access_count, :integer, null: false, default: 0)
      add(:last_accessed_at, :timestamptz)
      add(:created_at, :timestamptz, null: false)
      add(:cumulative_reward, :float, null: false, default: 0.0)
      add(:reward_count, :integer, null: false, default: 0)
    end

    create(index(nodes_table, [:tenant_id, :repo_id, :type]))

    create_vector_indexes(nodes_table, opts)
  end

  def down(opts) do
    prefix = Keyword.get(opts, :prefix, "mnemosyne_")

    drop_if_exists(table(:"#{prefix}node_metadata"))
    drop_if_exists(table(:"#{prefix}nodes"))
  end

  defp create_vector_indexes(table_name, opts) do
    index_type = Keyword.get(opts, :index_type, :hnsw)

    for node_type <- @node_types do
      execute(vector_index_sql(table_name, node_type, index_type, opts))
    end
  end

  defp vector_index_sql(table_name, node_type, :hnsw, opts) do
    with_clause = hnsw_with_clause(opts)

    """
    CREATE INDEX #{table_name}_#{node_type}_embedding_idx
    ON #{table_name}
    USING hnsw (embedding vector_cosine_ops)#{with_clause}
    WHERE type = '#{node_type}'
    """
  end

  defp vector_index_sql(table_name, node_type, :ivfflat, opts) do
    with_clause = ivfflat_with_clause(opts)

    """
    CREATE INDEX #{table_name}_#{node_type}_embedding_idx
    ON #{table_name}
    USING ivfflat (embedding vector_cosine_ops)#{with_clause}
    WHERE type = '#{node_type}'
    """
  end

  defp hnsw_with_clause(opts) do
    params =
      []
      |> maybe_add_param("m", opts[:hnsw_m])
      |> maybe_add_param("ef_construction", opts[:hnsw_ef_construction])

    case params do
      [] -> ""
      parts -> " WITH (#{Enum.join(parts, ", ")})"
    end
  end

  defp ivfflat_with_clause(opts) do
    case opts[:ivfflat_lists] do
      nil -> ""
      lists -> " WITH (lists = #{lists})"
    end
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: params ++ ["#{key} = #{value}"]
end
