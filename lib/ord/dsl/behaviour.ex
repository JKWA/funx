defmodule Funx.Ord.Dsl.Behaviour do
  @moduledoc """
  Behaviour for custom projection logic in the Ord DSL.

  A module implementing this behaviour must define `project/2`. The DSL calls
  `project/2` with the current value and any options given alongside the module
  inside the DSL.

  ## Examples

  A simple projection that extracts string length:

      iex> defmodule StringLength do
      ...>   @behaviour Funx.Ord.Dsl.Behaviour
      ...>
      ...>   @impl true
      ...>   def project(value, _opts) when is_binary(value) do
      ...>     String.length(value)
      ...>   end
      ...> end
      iex> StringLength.project("hello", [])
      5

  A projection with configurable options:

      iex> defmodule WeightedValue do
      ...>   @behaviour Funx.Ord.Dsl.Behaviour
      ...>
      ...>   @impl true
      ...>   def project(value, opts) do
      ...>     weight = Keyword.get(opts, :weight, 1.0)
      ...>     value * weight
      ...>   end
      ...> end
      iex> WeightedValue.project(10, weight: 2.5)
      25.0

  ## Usage in the DSL

      iex> defmodule NameLength do
      ...>   @behaviour Funx.Ord.Dsl.Behaviour
      ...>   @impl true
      ...>   def project(person, _opts) do
      ...>     String.length(person.name)
      ...>   end
      ...> end
      iex> defmodule ScoreMultiplier do
      ...>   @behaviour Funx.Ord.Dsl.Behaviour
      ...>   @impl true
      ...>   def project(person, opts) do
      ...>     multiplier = Keyword.get(opts, :multiplier, 1)
      ...>     person.score * multiplier
      ...>   end
      ...> end
      iex> use Funx.Ord.Dsl
      iex> ord do
      ...>   asc: NameLength
      ...>   desc: ScoreMultiplier, multiplier: 2
      ...> end

  The projection extracts a single comparable value from the input. The returned
  value will be compared using the `Funx.Ord` protocol (or `Funx.Ord.Any` if no
  specific implementation exists).
  """

  @doc """
  Projects a value to extract a comparable value.

  Arguments:

    * value
      The current value to project.

    * opts
      Module-specific options passed in the DSL, for example:

          asc: MyProjection, weight: 2.5

  Return value:

    The projected value that will be used for comparison. The returned value
    should implement `Funx.Ord` or be comparable using Elixir's built-in
    comparison operators.

  Examples:

      # Extract a field
      def project(person, _opts) do
        person.name
      end

      # Transform before comparison
      def project(value, _opts) do
        String.downcase(value)
      end

      # Use options
      def project(value, opts) do
        offset = Keyword.get(opts, :offset, 0)
        value + offset
      end
  """
  @callback project(value :: any(), opts :: keyword()) :: any()
end
