defmodule MnemosynePostgres.MixProject do
  use Mix.Project

  def project do
    [
      app: :mnemosyne_postgres,
      description: description(),
      package: package(),
      version: "0.1.0",
      elixir: "~> 1.19",
      test_coverage: [tool: ExCoveralls],
      docs: docs(),
      dialyzer: [
        plt_core_path: "_plts/core"
      ],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MnemosynePostgres.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.post": :test,
        "coveralls.github": :test,
        "coveralls.html": :test,
        "test.integration": :test
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.8", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: :dev},
      {:ecto, "~> 3.13"},
      {:ecto_sql, "~> 3.13"},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:excoveralls, "~> 0.18", only: [:dev, :test]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:assert_eventually, "~> 1.0", only: :test},
      {:mimic, "~> 2.0", only: :test},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mnemosyne, "~> 0.1"},
      {:pgvector, "~> 0.3"},
      {:postgrex, ">= 0.0.0"},
      {:recode, "~> 0.8", only: [:dev], runtime: false},
      {:splode, "~> 0.3"},
      {:telemetry, "~> 1.3"},
      {:tidewave, "~> 0.5", only: :dev, runtime: false},
      {:zoi, "~> 0.11"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.integration": ["test --only integration"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/edlontech/mnemosyne_postgres",
      extras: [
        {"README.md", title: "Overview"},
        {"LICENSE", title: "License"}
      ],
      groups_for_extras: [
        About: [
          "LICENSE"
        ]
      ],
      groups_for_modules: [],
      nest_modules_by_prefix: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description() do
    "A Pluggable, extensible, and performant agentic memory library for Elixir applications."
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/edlontech/mnemosyne_postgres"},
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end
end
