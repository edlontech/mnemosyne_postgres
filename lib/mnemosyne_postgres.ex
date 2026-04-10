defmodule MnemosynePostgres do
  @moduledoc """
  PostgreSQL + pgvector backend for the Mnemosyne agentic memory library.

  This library provides a `Mnemosyne.GraphBackend` implementation backed by
  PostgreSQL with pgvector for vector similarity search. It stores memory
  graph nodes, edges, and metadata using Ecto schemas and supports
  multi-tenant isolation via configurable table prefixes.

  ## Setup

      # Set as default backend in your supervision tree
      {Mnemosyne.Supervisor,
        config: config,
        llm: MyApp.LLM,
        embedding: MyApp.Embedding,
        backend: {MnemosynePostgres.Backend, repo: MyApp.Repo}}

      # Open repos -- repo_id is injected from the first argument
      Mnemosyne.open_repo("my-project")
      Mnemosyne.open_repo("my-project", tenant_id: "org-123")
  """
end
