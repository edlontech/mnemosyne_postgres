defmodule MnemosynePostgres.Queries.NodeQueries do
  @moduledoc """
  Ecto query builders for the nodes table.
  """

  import Ecto.Query
  import Pgvector.Ecto.Query

  alias MnemosynePostgres.Schema.Node

  @typep pgvector :: %Pgvector{data: binary()}

  @doc "Returns the `{table_name, schema}` source tuple for the nodes table."
  @spec source(map()) :: {String.t(), module()}
  def source(%{prefix: prefix}), do: {"#{prefix}nodes", Node}

  @doc "Base query scoped to the current tenant."
  @spec base(map()) :: Ecto.Query.t()
  def base(state) do
    from(n in source(state), where: n.tenant_id == ^state.tenant_id)
  end

  @doc "Base query scoped to the current tenant and repo."
  @spec scoped(map()) :: Ecto.Query.t()
  def scoped(state) do
    from(n in base(state), where: n.repo_id == ^state.repo_id)
  end

  @doc "Filters the query to only include nodes with the given IDs."
  @spec by_ids(Ecto.Query.t(), [String.t()]) :: Ecto.Query.t()
  def by_ids(query, ids) do
    from(n in query, where: n.id in ^ids)
  end

  @doc "Filters the query to only include nodes of the given types."
  @spec by_types(Ecto.Query.t(), [atom()]) :: Ecto.Query.t()
  def by_types(query, types) do
    type_strings = Enum.map(types, &Atom.to_string/1)
    from(n in query, where: n.type in ^type_strings)
  end

  @doc "Returns nodes ordered by cosine distance to the query embedding."
  @spec vector_search(map(), atom(), pgvector(), non_neg_integer()) :: Ecto.Query.t()
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
