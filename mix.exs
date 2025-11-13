defmodule Funx.MixProject do
  use Mix.Project

  @version "0.1.6"

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
          "usage-rules.md": [
            title: "Funx Usage Rules",
            filename: "usage-rules"
          ],
          "usage-rules/appendable.md": [
            title: "Funx.Appendable Usage Rules",
            filename: "appendable-usage-rules"
          ],
          "usage-rules/eq.md": [
            title: "Funx.Eq Usage Rules",
            filename: "eq-usage-rules"
          ],
          "usage-rules/errors_validation_error.md": [
            title: "Funx.Errors.ValidationError Usage Rules",
            filename: "errors-validation-error-usage-rules"
          ],
          "usage-rules/foldable.md": [
            title: "Funx.Foldable Usage Rules",
            filename: "foldable-usage-rules"
          ],
          "usage-rules/list.md": [
            title: "Funx.List Usage Rules",
            filename: "list-usage-rules"
          ],
          "usage-rules/monad.md": [
            title: "Funx.Monad Usage Rules",
            filename: "monad-usage-rules"
          ],
          "usage-rules/monad_either.md": [
            title: "Funx.Monad.Either Usage Rules",
            filename: "monad-either-usage-rules"
          ],
          "usage-rules/monad_effect.md": [
            title: "Funx.Monad.Effect Usage Rules",
            filename: "monad-effect-usage-rules"
          ],
          "usage-rules/monad_identity.md": [
            title: "Funx.Monad.Identity Usage Rules",
            filename: "monad-identity-usage-rules"
          ],
          "usage-rules/monad_maybe.md": [
            title: "Funx.Monad.Maybe Usage Rules",
            filename: "monad-maybe-usage-rules"
          ],
          "usage-rules/monad_reader.md": [
            title: "Funx.Monad.Reader Usage Rules",
            filename: "monad-reader-usage-rules"
          ],
          "usage-rules/monoid.md": [
            title: "Funx.Monoid Usage Rules",
            filename: "monoid-usage-rules"
          ],
          "usage-rules/ord.md": [
            title: "Funx.Ord Usage Rules",
            filename: "ord-usage-rules"
          ],
          "usage-rules/predicate.md": [
            title: "Funx.Predicate Usage Rules",
            filename: "predicate-usage-rules"
          ],
          "usage-rules/utils.md": [
            title: "Funx.Utils Usage Rules",
            filename: "utils-usage-rules"
          ]
        ],
        groups_for_extras: [
          "LLM Usage Rules": [
            "usage-rules.md",
            "usage-rules/appendable.md",
            "usage-rules/eq.md",
            "usage-rules/errors_validation_error.md",
            "usage-rules/foldable.md",
            "usage-rules/list.md",
            "usage-rules/monad.md",
            "usage-rules/monad_either.md",
            "usage-rules/monad_effect.md",
            "usage-rules/monad_identity.md",
            "usage-rules/monad_maybe.md",
            "usage-rules/monad_reader.md",
            "usage-rules/monoid.md",
            "usage-rules/ord.md",
            "usage-rules/predicate.md",
            "usage-rules/utils.md"
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
          "Website" => "https://www.funxlib.com",
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
