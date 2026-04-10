defmodule MnemosynePostgres.Queries.NodeQueries do
  @moduledoc false

  import Ecto.Query
  import Pgvector.Ecto.Query

  alias MnemosynePostgres.Schema.Node

  def source(%{prefix: prefix}), do: {"#{prefix}nodes", Node}

  def base(state) do
    from(n in source(state), where: n.tenant_id == ^state.tenant_id)
  end

  def scoped(state) do
    from(n in base(state), where: n.repo_id == ^state.repo_id)
  end

  def by_ids(query, ids) do
    from(n in query, where: n.id in ^ids)
  end

  def by_types(query, types) do
    type_strings = Enum.map(types, &Atom.to_string/1)
    from(n in query, where: n.type in ^type_strings)
  end

  def vector_search(state, type, query_embedding, limit) do
    type_str = Atom.to_string(type)

    from(n in source(state),
      where: n.tenant_id == ^state.tenant_id,
      where: n.repo_id == ^state.repo_id,
      where: n.type == ^type_str,
      where: not is_nil(n.embedding),
      order_by: cosine_distance(n.embedding, ^query_embedding),
      limit: ^limit
    )
  end
end
