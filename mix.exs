defmodule Funx.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :funx,
      version: @version,
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
        source_ref: "v#{@version}",
        source_url_pattern: "https://github.com/JKWA/funx/blob/v#{@version}/%{path}#L%{line}",
        canonical: "https://hexdocs.pm/funx"
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
          "Functional programming abstractions for Elixir (Beta release: APIs may change before 1.0)",
        licenses: ["MIT"],
        maintainers: ["Joseph Koski"],
        links: %{
          "GitHub" => "https://github.com/JKWA/funx",
          "Docs" => "https://jkwa.github.io/funx/readme.html"
        },
        files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test], runtime: false},
      {:telemetry, "~> 1.0"}
    ]
  end
end
