defmodule Funx.Ord.Dsl do
  @moduledoc """
  The `Funx.Ord.Dsl` module provides a declarative syntax for building total orderings over complex data structures.

  The DSL compiles at compile time into efficient `Ord` compositions using `contramap`, `reverse`, and `concat`. This eliminates the need to manually compose ordering functions while providing a clear, readable syntax for expressing multi-field lexicographic ordering.

  Each projection extracts a comparable value from the input and specifies a direction (`:asc` or `:desc`). The DSL handles optional fields, nested structures, custom projections, and type filtering through a unified interface.

  ## Deterministic Ordering

  The DSL always produces deterministic total orderings by automatically appending an
  identity projection as the final tiebreaker. This means:

    - When all projections result in equality, the ordering falls back to the value's
      `Ord` protocol implementation
    - Custom orderings are refinements of the domain's natural ordering
    - No arbitrary tiebreaking via insertion order or Elixir term ordering
    - Sorts are reproducible and deterministic across runs

  For example, if `Product` has `ord_for(Product, :amount)` defining its natural ordering,
  then `ord do asc :name end` will sort by name first, then by amount for ties.

  This module is useful for:

    - Multi-field sorting with different directions per field
    - Handling optional values explicitly with `or_else` fallbacks
    - Type partitioning to group heterogeneous data before ordering
    - Custom ordering logic via behaviour modules or projection functions
    - Nested field access through lenses and prisms
    - Building deterministic orderings that respect domain semantics

  ### Directions

    - `:asc` - Ascending order (smallest to largest)
    - `:desc` - Descending order (largest to smallest)

  ### Projection Types

  The DSL supports eight projection forms, all normalized at compile time:

    - Atom - Field access via `Prism.key(atom)`. Safe for nil values with `Nothing < Just` semantics.
    - Atom with or_else - Optional field via `{Prism.key(atom), or_else}`. Treats `nil` as the fallback value.
    - Function - Direct projection `fn x -> ... end` or `&fun/1`. Must return a comparable value.
    - Lens - Explicit lens for nested access. Total but raises on missing keys or nil intermediate values. Must be explicit: `Lens.key(:field)`.
    - Prism - Explicit prism for optional fields. Returns `Maybe` with `Nothing < Just` semantics.
    - Prism with or_else - Explicit prism `{Prism.t(), or_else}` for optional with fallback.
    - Behaviour - Custom ordering via `c:Funx.Ord.Dsl.Behaviour.ord/1`.
    - Ord variable - Existing ord map to compose or reverse. Enables reusable ordering definitions.

  > Note: Atoms use Prism by default for safety. Use explicit `Lens.key(:field)` when you need
  > total access that raises on missing keys.

  ### Utility Functions

  Orderings created with `ord/1` return a `%Funx.Monoid.Ord{}` struct compatible with:

    - `Funx.Ord.Utils.compare/3` - Compare two values, returns `:lt`, `:eq`, or `:gt`.
    - `Funx.Ord.Utils.comparator/1` - Convert to an Elixir comparator function for `Enum.sort/2`.
    - `Funx.Ord.Utils.min/3` - Returns the lesser of two values.
    - `Funx.Ord.Utils.max/3` - Returns the greater of two values.
    - `Funx.List.sort/2` - Sort a list using the ordering.

  ## Examples

  Simple multi-field ordering:

      iex> use Funx.Ord.Dsl
      iex> defmodule Person, do: defstruct [:name, :age]
      iex> ord_person = ord do
      ...>   asc :name
      ...>   desc :age
      ...> end
      iex> alice = %Person{name: "Alice", age: 30}
      iex> bob = %Person{name: "Bob", age: 25}
      iex> Funx.Ord.Utils.compare(alice, bob, ord_person)
      :lt

  Optional fields with or_else:

      iex> use Funx.Ord.Dsl
      iex> defmodule Item, do: defstruct [:name, :score]
      iex> ord_item = ord do
      ...>   asc :score, or_else: 0
      ...>   asc :name
      ...> end
      iex> item1 = %Item{name: "A", score: nil}
      iex> item2 = %Item{name: "B", score: 10}
      iex> Funx.Ord.Utils.compare(item1, item2, ord_item)
      :lt

  Function projections:

      iex> use Funx.Ord.Dsl
      iex> ord_length = ord do
      ...>   asc &String.length/1
      ...> end
      iex> items = ["apple", "kiwi", "banana"]
      iex> Enum.sort(items, Funx.Ord.Utils.comparator(ord_length))
      ["kiwi", "apple", "banana"]

  Composing ord variables:

      iex> use Funx.Ord.Dsl
      iex> defmodule Item, do: defstruct [:name, :priority, :created_at]
      iex> base_ord = ord do
      ...>   asc :name
      ...> end
      iex> combined_ord = ord do
      ...>   desc :priority, or_else: 0
      ...>   asc base_ord
      ...> end
      iex> item1 = %Item{name: "A", priority: 1, created_at: nil}
      iex> item2 = %Item{name: "B", priority: 1, created_at: nil}
      iex> Funx.Ord.Utils.compare(item1, item2, combined_ord)
      :lt

  ## Compile-Time Behavior

  The DSL expands into direct `Ord` function calls at compile time with zero runtime overhead:

      ord do
        asc :name
        desc :age
      end

  Compiles to:

      concat([
        contramap(Prism.key(:name)),
        reverse(contramap(Prism.key(:age)))
      ])

  ## Protocol Dispatch

  The DSL leverages the `Funx.Ord` protocol for custom types. Projected values can be any type that implements `Ord`:

      defmodule Address do
        defstruct [:city, :state]
      end

      defimpl Funx.Ord, for: Address do
        def lt?(a, b), do: {a.state, a.city} < {b.state, b.city}
        def le?(a, b), do: {a.state, a.city} <= {b.state, b.city}
        def gt?(a, b), do: {a.state, a.city} > {b.state, b.city}
        def ge?(a, b), do: {a.state, a.city} >= {b.state, b.city}
      end

      ord do
        asc :address  # Uses Funx.Ord.Address protocol implementation
      end

  ## DSL Usage

  Import the DSL with `use Funx.Ord.Dsl`:

      use Funx.Ord.Dsl

      ord do
        desc :priority
        asc :created_at
        asc :name
      end

  This creates a total ordering that first sorts by priority (descending), then by creation time (ascending), then by name (ascending) for tie-breaking.
  """

  # credo:disable-for-this-file Credo.Check.Design.AliasUsage
  alias Funx.Ord.Dsl.Executor
  alias Funx.Ord.Dsl.Parser

  defmacro __using__(_opts) do
    quote do
      import Funx.Ord.Dsl
    end
  end

  # ============================================================================
  # PUBLIC MACROS (ENTRY POINT)
  # ============================================================================

  @doc """
  Creates an ordering from a block of projection specifications.

  Returns a `%Funx.Monoid.Ord{}` struct that can be used with `Funx.Ord.Utils`
  functions like `compare/3`, `max/3`, `min/3`, or `comparator/1`.

  ## Examples

      ord do
        asc :name
        desc :age
      end

      ord do
        asc :score, or_else: 0
        desc &String.length(&1.bio)
      end
  """
  defmacro ord(do: block) do
    compile_ord(block, __CALLER__)
  end

  # ============================================================================
  # ORD COMPILATION (COMPILE-TIME)
  # ============================================================================

  defp compile_ord(block, caller_env) do
    # Parse operations into Step structs
    steps = Parser.parse_operations(block, caller_env)

    # Execute (compile) steps to quoted AST
    Executor.execute_steps(steps)
  end
end
