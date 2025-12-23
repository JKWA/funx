defmodule Funx.Ord.Dsl do
  @moduledoc """
  Provides the `ord/1` and `ord/2` macros for building declarative ordering logic.

  The DSL lets you express complex multi-field ordering without manually composing
  `contramap`, `reverse`, and `concat` calls. Each projection is specified with a
  direction (`:asc` or `:desc`), and the DSL compiles to efficient `Ord` composition.

  ## Supported Projections

  - **Atom** - Creates `Lens.key(atom)` for field access
  - **Atom with or_else** - Creates `{Prism.key(atom), or_else}` for optional fields
  - **Function** - Direct projection function
  - **Lens** - Explicit lens for nested access
  - **Prism tuple** - `{Prism, or_else}` for optional with fallback
  - **Bare Prism** - Returns `Maybe`, uses `Maybe.lift_ord` (Nothing < Just)
  - **Behaviour module** - Custom projection via `Funx.Ord.Dsl.Behaviour`

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

  ## Compile-Time Behavior

  The DSL compiles to direct function calls at **compile time**. There is no runtime
  overhead for the DSL itself - it expands into the same code you would write manually
  with `contramap`, `reverse`, and `concat`.

  Example showing compile-time expansion:

      ord do
        asc :name
        desc :age
      end

  Compiles to:

      concat([
        contramap(Lens.key(:name)),
        reverse(contramap(Lens.key(:age)))
      ])

  ## Direction Keywords

  - `:asc` - Ascending order (smallest to largest)
  - `:desc` - Descending order (largest to smallest)

  ## Protocol Dispatch

  The DSL leverages the `Funx.Ord` protocol. Extracted values can be any type
  that implements `Ord`:

      defmodule Address do
        defstruct [:city, :state]
      end

      defimpl Funx.Ord, for: Address do
        def lt?(a, b), do: {a.state, a.city} < {b.state, b.city}
        # ... other functions
      end

      ord do
        asc :address  # Uses Funx.Ord.Address automatically
      end
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
