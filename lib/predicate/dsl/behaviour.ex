defmodule Funx.Predicate.Dsl.Behaviour do
  @moduledoc """
  Behaviour for custom predicate logic in the Predicate DSL.

  Implement this behaviour to define reusable predicates that can be
  used with `on` directives in the DSL.

  This is useful for teams that want to create reusable, configurable
  predicates without repeating logic across the codebase.

  ## Basic Example

      defmodule IsActive do
        @behaviour Funx.Predicate.Dsl.Behaviour

        @impl true
        def pred(_opts) do
          fn user -> user.active end
        end
      end

      # In DSL
      use Funx.Predicate

      pred do
        on IsActive  # Checks if active
      end

  ## With Options

      defmodule HasMinimumAge do
        @behaviour Funx.Predicate.Dsl.Behaviour

        @impl true
        def pred(opts) do
          minimum_age = Keyword.get(opts, :minimum, 18)

          fn user -> user.age >= minimum_age end
        end
      end

      # In DSL
      pred do
        on HasMinimumAge, minimum: 21
      end

  ## Why Use This?

  - **Reusable**: Define predicates once, use everywhere
  - **Configurable**: Built-in support for options
  - **Testable**: Predicates can be unit tested independently
  - **Discoverable**: All predicates in one module namespace

  The returned predicate is a function `(any() -> boolean())` that will be
  composed with other predicates using the DSL's combinator logic.
  """

  @doc """
  Returns a predicate function.

  Takes options and returns a predicate function `(any() -> boolean())`.

  ## Arguments

    * `opts` - Keyword list of options passed from the DSL

  ## Return Value

  A predicate function with the signature:

      (any() -> boolean())

  ## Examples

      # Simple predicate
      def pred(_opts) do
        fn user -> user.active end
      end

      # With options
      def pred(opts) do
        field = Keyword.get(opts, :field, :active)
        fn item -> Map.get(item, field) end
      end

      # Complex logic
      def pred(opts) do
        min_age = Keyword.get(opts, :min_age, 18)
        max_age = Keyword.get(opts, :max_age, 65)

        fn user ->
          user.age >= min_age and user.age <= max_age
        end
      end

  Most implementations return simple predicate functions that check
  specific conditions on the input value.
  """
  @callback pred(opts :: keyword()) :: Funx.Predicate.t()
end
