defmodule Funx.Eq.Dsl.Behaviour do
  @moduledoc """
  Behaviour for custom projection logic in the Eq DSL.

  A module implementing this behaviour must define `project/2`. The DSL calls
  `project/2` with the current value and any options given alongside the module
  inside the DSL.

  ## Examples

  A simple projection that extracts string length:

      iex> defmodule StringLength do
      ...>   @behaviour Funx.Eq.Dsl.Behaviour
      ...>
      ...>   @impl true
      ...>   def project(value, _opts) when is_binary(value) do
      ...>     String.length(value)
      ...>   end
      ...> end
      iex> StringLength.project("hello", [])
      5

  A projection with configurable options:

      iex> defmodule NormalizedValue do
      ...>   @behaviour Funx.Eq.Dsl.Behaviour
      ...>
      ...>   @impl true
      ...>   def project(value, opts) do
      ...>     case_sensitive = Keyword.get(opts, :case_sensitive, true)
      ...>     if case_sensitive, do: value, else: String.downcase(value)
      ...>   end
      ...> end
      iex> NormalizedValue.project("Hello", case_sensitive: false)
      "hello"

  ## Usage in the DSL

      iex> defmodule NameLength do
      ...>   @behaviour Funx.Eq.Dsl.Behaviour
      ...>   @impl true
      ...>   def project(person, _opts) do
      ...>     String.length(person.name)
      ...>   end
      ...> end
      iex> use Funx.Eq.Dsl
      iex> eq do
      ...>   on NameLength
      ...> end

  The projection extracts a single comparable value from the input. The returned
  value will be compared using the `Funx.Eq` protocol.
  """

  @doc """
  Projects a value to extract a comparable value.

  Arguments:

    * value
      The current value to project.

    * opts
      Module-specific options passed in the DSL, for example:

          on MyProjection, case_sensitive: false

  Return value:

    The projected value that will be used for comparison. The returned value
    should implement `Funx.Eq` or be comparable using Elixir's built-in
    equality operators.

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
        default = Keyword.get(opts, :default, "")
        value || default
      end
  """
  @callback project(value :: any(), opts :: keyword()) :: any()
end
