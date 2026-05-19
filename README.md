# MnemosynePostgres

PostgreSQL + pgvector backend for [Mnemosyne](https://github.com/edlontech/mnemosyne), the task-agnostic agentic memory library.

This library implements the `Mnemosyne.GraphBackend` behaviour, persisting the knowledge graph in PostgreSQL with vector similarity search powered by pgvector.

## Installation

Add `mnemosyne_postgres` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mnemosyne_postgres, "~> 0.1.1"} # x-release-please-version
  ]
end
```

## Setup

### 1. Enable pgvector

Ensure the `pgvector` extension is available in your PostgreSQL instance (v0.5+).

### 2. Create a migration

```elixir
defmodule MyApp.Repo.Migrations.AddMnemosyne do
  use Ecto.Migration

  def up, do: MnemosynePostgres.Migrations.up(version: 1, embedding_dimensions: 1536)
  def down, do: MnemosynePostgres.Migrations.down(version: 1)
end
```

#### Migration options

| Option | Default | Description |
|--------|---------|-------------|
| `:version` | `1` | Target migration version |
| `:embedding_dimensions` | -- (required) | Dimensionality of your embedding vectors |
| `:index_type` | `:hnsw` | `:hnsw` or `:ivfflat` |
| `:hnsw_m` | pgvector default | Max connections per HNSW layer |
| `:hnsw_ef_construction` | pgvector default | Dynamic candidate list size for HNSW |
| `:ivfflat_lists` | pgvector default | Number of inverted lists for IVFFlat |
| `:prefix` | `"mnemosyne_"` | Table name prefix |

### 3. Configure the backend

Set the default backend in your supervision tree so you don't repeat it on every `open_repo` call:

```elixir
children = [
  {Mnemosyne.Supervisor,
    config: config,
    llm: MyApp.LLM,
    embedding: MyApp.Embedding,
    backend: {MnemosynePostgres.Backend, repo: MyApp.Repo}}
]
```

Then open repos -- `repo_id` is injected automatically from the first argument:

```elixir
# Single-tenant (tenant_id defaults to "default")
{:ok, _pid} = Mnemosyne.open_repo("my-project")

# Multi-tenant
{:ok, _pid} = Mnemosyne.open_repo("my-project", tenant_id: "org-123")
```

#### Backend options

| Option | Default | Description |
|--------|---------|-------------|
| `:repo` | -- (required) | Your Ecto repo module |
| `:tenant_id` | `"default"` | Tenant identifier for multi-tenant isolation |
| `:prefix` | `"mnemosyne_"` | Table name prefix (must match migration) |

## Storage Model

Nodes are stored in a single polymorphic `nodes` table with JSONB data, vector embeddings, and JSONB link maps. Metadata lives in a separate `node_metadata` table.

```
nodes                          node_metadata
+-----------+-----------+      +-------------+----------+
| id (uuid) | type      |      | node_id     | accessed |
| data      | embedding |      | reward      | recency  |
| links     | tenant_id |      | frequency   |          |
| repo_id   | inserted  |      +-------------+----------+
+-----------+-----------+
```

Vector indexes (HNSW or IVFFlat) are created per node type via partial indexes, avoiding the performance penalty of post-filtering across the full table.

## Versioned Migrations

When a new schema version is released, create a new migration pointing to the next version:

```elixir
defmodule MyApp.Repo.Migrations.UpgradeMnemosyneV2 do
  use Ecto.Migration

  def up, do: MnemosynePostgres.Migrations.up(version: 2, embedding_dimensions: 1536)
  def down, do: MnemosynePostgres.Migrations.down(version: 2)
end
```

The migration system tracks the current version via table comments and runs only the deltas.

## Telemetry

All backend operations emit `[:mnemosyne_postgres, ...]` telemetry events. See `MnemosynePostgres.Telemetry` for the full list of events and their measurements.
