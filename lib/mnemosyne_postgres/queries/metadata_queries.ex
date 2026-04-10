defmodule MnemosynePostgres.Queries.MetadataQueries do
  @moduledoc false

  import Ecto.Query

  alias MnemosynePostgres.Schema.NodeMetadata

  def source(%{prefix: prefix}), do: {"#{prefix}node_metadata", NodeMetadata}

  def base(state) do
    from(m in source(state), where: m.tenant_id == ^state.tenant_id)
  end

  def by_node_ids(query, node_ids) do
    from(m in query, where: m.node_id in ^node_ids)
  end
end
