defmodule MnemosynePostgres.NodeSerializer do
  @moduledoc """
  Round-trip conversion between Mnemosyne node structs and DB-friendly maps.

  `to_row/3` produces maps suitable for `Repo.insert_all`.
  `from_row/1` converts DB rows (schema structs or plain maps) back to Mnemosyne node structs.
  """

  alias Mnemosyne.Graph.Node.Episodic
  alias Mnemosyne.Graph.Node.Intent
  alias Mnemosyne.Graph.Node.Procedural
  alias Mnemosyne.Graph.Node.Semantic
  alias Mnemosyne.Graph.Node.Source
  alias Mnemosyne.Graph.Node.Subgoal
  alias Mnemosyne.Graph.Node.Tag
  alias MnemosynePostgres.Ecto.Links

  @data_fields %{
    semantic: [:proposition, :confidence],
    episodic: [:observation, :action, :state, :subgoal, :reward, :trajectory_id],
    procedural: [:instruction, :condition, :expected_outcome, :return_score],
    subgoal: [:description, :parent_goal],
    source: [:episode_id, :step_index, :plain_text],
    tag: [:label],
    intent: [:description]
  }

  @type_to_module %{
    semantic: Semantic,
    episodic: Episodic,
    procedural: Procedural,
    subgoal: Subgoal,
    source: Source,
    tag: Tag,
    intent: Intent
  }

  @spec to_row(struct(), String.t(), String.t()) :: map()
  def to_row(node, tenant_id, repo_id) do
    type = Mnemosyne.Graph.Node.node_type(node)
    fields = Map.fetch!(@data_fields, type)

    %{
      id: node.id,
      tenant_id: tenant_id,
      repo_id: repo_id,
      type: Atom.to_string(type),
      data: serialize_data(node, fields),
      embedding: node.embedding,
      links: node.links,
      created_at: node.created_at
    }
  end

  @spec from_row(map()) :: struct()
  def from_row(%{type: type_str} = row) do
    type = String.to_existing_atom(type_str)
    module = Map.fetch!(@type_to_module, type)
    fields = Map.fetch!(@data_fields, type)

    base = %{
      id: row.id,
      embedding: deserialize_embedding(row.embedding),
      links: deserialize_links(row.links),
      created_at: row.created_at
    }

    data_fields = deserialize_data(row.data, fields)
    struct!(module, Map.merge(base, data_fields))
  end

  defp serialize_data(node, fields) do
    Map.new(fields, fn field ->
      {Atom.to_string(field), Map.get(node, field)}
    end)
  end

  defp deserialize_data(data, fields) do
    Map.new(fields, fn field ->
      {field, Map.get(data, Atom.to_string(field))}
    end)
  end

  defp deserialize_links(links) when is_map(links) do
    case Enum.at(links, 0) do
      {key, _} when is_atom(key) ->
        links

      _ ->
        {:ok, loaded} = Links.load(links)
        loaded
    end
  end

  defp deserialize_links(_), do: Mnemosyne.Graph.Edge.empty_links()

  defp deserialize_embedding(nil), do: nil
  defp deserialize_embedding(%Pgvector{} = vec), do: Pgvector.to_list(vec)
  defp deserialize_embedding(list) when is_list(list), do: list
end
