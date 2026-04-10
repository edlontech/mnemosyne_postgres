defmodule MnemosynePostgres.Telemetry do
  @moduledoc """
  Telemetry events for `MnemosynePostgres`.

  All events are emitted via `:telemetry.span/3`, which automatically
  produces `:start`, `:stop`, and `:exception` suffixed events.

  ## Events

  ### `[:mnemosyne_postgres, :find_candidates]`

  Emitted when searching for candidate nodes via vector similarity.

    * **Metadata:** `%{node_types: [atom()], tenant_id: String.t(), repo_id: String.t()}`
    * **Extra stop measurements:** `%{candidate_count: non_neg_integer()}`

  ### `[:mnemosyne_postgres, :apply_changeset]`

  Emitted when applying a changeset (inserts, links, metadata).

    * **Metadata:** `%{tenant_id: String.t(), repo_id: String.t()}`
    * **Extra stop measurements:** `%{nodes_inserted: non_neg_integer()}`

  ### `[:mnemosyne_postgres, :delete_nodes]`

  Emitted when deleting nodes.

    * **Metadata:** `%{tenant_id: String.t(), repo_id: String.t(), node_count: non_neg_integer()}`

  ### `[:mnemosyne_postgres, :get_node]`

  Emitted when fetching a single node by ID.

    * **Metadata:** `%{tenant_id: String.t(), repo_id: String.t(), node_id: String.t()}`

  ### `[:mnemosyne_postgres, :get_nodes_by_type]`

  Emitted when fetching all nodes of given types.

    * **Metadata:** `%{tenant_id: String.t(), repo_id: String.t(), node_types: [atom()]}`
  """

  @prefix [:mnemosyne_postgres]

  @spec span(atom(), map(), (-> {result, map()})) :: result when result: term()
  def span(event, metadata, fun) do
    :telemetry.span(@prefix ++ [event], metadata, fun)
  end
end
