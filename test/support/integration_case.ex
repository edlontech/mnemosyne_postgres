defmodule MnemosynePostgres.IntegrationCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  @llm_model "openrouter:google/gemini-3-flash-preview"
  @embedding_model "openai:text-embedding-3-small"
  @prefix "integration_"

  using do
    quote do
      @moduletag :integration

      alias MnemosynePostgres.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MnemosynePostgres.DataCase
    end
  end

  setup tags do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(MnemosynePostgres.Repo, shared: not tags[:async])

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    openai_key = require_env!("OPENAI_API_KEY")
    openrouter_key = require_env!("OPENROUTER_API_KEY")

    %{
      openai_key: openai_key,
      openrouter_key: openrouter_key,
      llm_model: @llm_model,
      embedding_model: @embedding_model,
      prefix: @prefix
    }
  end

  defp require_env!(var) do
    case System.get_env(var) do
      nil ->
        raise ExUnit.AssertionError,
          message: "#{var} not set, required for integration tests"

      key ->
        key
    end
  end
end
