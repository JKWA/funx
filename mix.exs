defmodule Funx.MixProject do
  use Mix.Project

  @version "0.1.5"

  def project do
    [
      app: :funx,
      version: @version,
      elixir: "~> 1.16 or ~> 1.17",
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
        extras: [
          "README.md",
          "CHANGELOG.md",
          "LICENSE",
          "lib/usage-rules.md": [
            title: "Funx Usage Rules",
            filename: "usage-rules"
          ],
          "lib/appendable/usage-rules.md": [
            title: "Funx.Appendable Usage Rules",
            filename: "appendable-usage-rules"
          ],
          "lib/eq/usage-rules.md": [
            title: "Funx.Eq Usage Rules",
            filename: "eq-usage-rules"
          ],
          "lib/errors/validation_error/usage-rules.md": [
            title: "Funx.Errors.ValidationError Usage Rules",
            filename: "errors-validation-error-usage-rules"
          ],
          "lib/list/usage-rules.md": [
            title: "Funx.List Usage Rules",
            filename: "list-usage-rules"
          ],
          "lib/monad/usage-rules.md": [
            title: "Funx.Monad Usage Rules",
            filename: "monad-usage-rules"
          ],
          "lib/monad/either/usage-rules.md": [
            title: "Funx.Monad.Either Usage Rules",
            filename: "monad-either-usage-rules"
          ],
          "lib/monad/effect/usage-rules.md": [
            title: "Funx.Monad.Effect Usage Rules",
            filename: "monad-effect-usage-rules"
          ],
          "lib/monad/identity/usage-rules.md": [
            title: "Funx.Monad.Identity Usage Rules",
            filename: "monad-identity-usage-rules"
          ],
          "lib/monad/maybe/usage-rules.md": [
            title: "Funx.Monad.Maybe Usage Rules",
            filename: "monad-maybe-usage-rules"
          ],
          "lib/monad/reader/usage-rules.md": [
            title: "Funx.Monad.Reader Usage Rules",
            filename: "monad-reader-usage-rules"
          ],
          "lib/monoid/usage-rules.md": [
            title: "Funx.Monoid Usage Rules",
            filename: "monoid-usage-rules"
          ],
          "lib/ord/usage-rules.md": [
            title: "Funx.Ord Usage Rules",
            filename: "ord-usage-rules"
          ],
          "lib/predicate/usage-rules.md": [
            title: "Funx.Predicate Usage Rules",
            filename: "predicate-usage-rules"
          ],
          "lib/utils/usage-rules.md": [
            title: "Funx.Utils Usage Rules",
            filename: "utils-usage-rules"
          ]
        ],
        groups_for_extras: [
          "Usage Rules": [
            "lib/usage-rules.md",
            "lib/appendable/usage-rules.md",
            "lib/eq/usage-rules.md",
            "lib/errors/validation_error/usage-rules.md",
            "lib/list/usage-rules.md",
            "lib/monad/usage-rules.md",
            "lib/monad/either/usage-rules.md",
            "lib/monad/effect/usage-rules.md",
            "lib/monad/identity/usage-rules.md",
            "lib/monad/maybe/usage-rules.md",
            "lib/monad/reader/usage-rules.md",
            "lib/monoid/usage-rules.md",
            "lib/ord/usage-rules.md",
            "lib/predicate/usage-rules.md",
            "lib/utils/usage-rules.md"
          ]
        ],
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
          "Docs" => "https://hexdocs.pm/funx",
          "GitHub" => "https://github.com/JKWA/funx",
          "Advanced FP with Elixir (Book)" =>
            "https://pragprog.com/titles/jkelixir/advanced-functional-programming-with-elixir"
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
