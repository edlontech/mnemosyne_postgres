defmodule MnemosynePostgres.Schema.Node do
  @moduledoc """
  Ecto schema for the polymorphic `mnemosyne_nodes` table.

  Stores all node types (semantic, episodic, procedural, etc.) in a single
  table with JSONB `data` and `links` fields and a pgvector `embedding` column.
  """
  use Ecto.Schema

  @type t :: %__MODULE__{}
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts false

  schema "mnemosyne_nodes" do
    field :tenant_id, :string
    field :repo_id, :string
    field :type, :string
    field :data, :map, default: %{}
    field :embedding, Pgvector.Ecto.Vector
    field :links, :map, default: %{}
    field :created_at, :utc_datetime_usec
    field :distance, :float, virtual: true
  end
end
