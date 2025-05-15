defmodule Funx.MixProject do
  use Mix.Project

  def project do
    [
      app: :funx,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:elixir, :mix],
        plt_core_path: "_build/#{Mix.env()}",
        plt_file: {:no_warn, "_build/#{Mix.env()}/dialyzer.plt"}
      ],
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md", "LICENSE"],
        filter_prefix: "Examples",
        source_url: "https://github.com/JKWA/funx",
        source_url_pattern: "https://github.com/JKWA/funx/blob/main/%{path}#L%{line}"
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      package: [
        name: "funx",
        description:
          "Functional programming abstractions for Elixir, providing monads and related tools.",
        licenses: ["MIT"],
        maintainers: ["Joseph Koski"],
        links: %{
          "GitHub" => "https://github.com/JKWA/funx",
          "Docs" => "https://jkwa.github.io/funx/readme.html"
        },
        exclude_patterns: ["examples/**", "test/**", "*.md"]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "examples"]
  defp elixirc_paths(_), do: ["lib", "examples"]

  def application do
    [
      extra_applications: [:logger, :observer, :wx, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:earmark, "~> 1.4", only: :dev, runtime: false},
      {:makeup_elixir, "~> 0.16", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test], runtime: false},
      {:castore, "~> 1.0", only: [:dev, :test]},
      {:telemetry, "~> 1.0"}
    ]
  end
end
