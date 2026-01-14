defmodule Funx.Ord do
  @moduledoc """
  Provides utilities and DSL for working with the `Funx.Ord.Protocol`.

  This module combines:
  - Utility functions for ordering and comparison
  - A declarative DSL for building complex orderings

  ## Utility Functions

  These functions work with types that support Elixir's comparison operators
  or implement the `Funx.Ord.Protocol`:

  - `contramap/2` - Transform ordering by applying a projection
  - `compare/3` - Compare two values, returns `:lt`, `:eq`, or `:gt`
  - `max/3`, `min/3` - Find maximum or minimum of two values
  - `clamp/4`, `between/4` - Range operations
  - `reverse/1` - Reverse ordering logic
  - `comparator/1` - Convert to Elixir comparator for `Enum.sort/2`
  - `to_eq/1` - Convert to equality comparator
  - `append/2`, `concat/1` - Combine multiple orderings

  ## DSL

  The DSL provides a declarative syntax for building total orderings over complex data structures.

  Use `use Funx.Ord` to import both utilities and DSL:

      use Funx.Ord

      ord do
        asc :name
        desc :age
      end

  The DSL compiles at compile time into efficient compositions using `contramap`, `reverse`, and `concat`,
  eliminating the need to manually compose ordering functions.

  ### Directions

    - `:asc` - Ascending order (smallest to largest)
    - `:desc` - Descending order (largest to smallest)

  ### Projection Types

    - Atom - Field access via `Prism.key(atom)`. Safe for nil values.
    - Atom with or_else - Optional field with fallback value
    - Function - Direct projection `fn x -> ... end` or `&fun/1`
    - Lens - Explicit lens for nested access
    - Prism - Explicit prism for optional fields
    - Prism with or_else - Optional with fallback
    - Behaviour - Custom ordering via `Funx.Ord.Dsl.Behaviour`
    - Ord variable - Existing ord map to compose

  See `Funx.Ord.Dsl.Behaviour` for implementing custom ordering logic.
  """

  @type ord_map() :: %{
          lt?: (any(), any() -> boolean()),
          le?: (any(), any() -> boolean()),
          gt?: (any(), any() -> boolean()),
          ge?: (any(), any() -> boolean())
        }

  @type ord_t() :: Funx.Ord.Protocol.t() | ord_map()

  import Funx.Monoid.Utils, only: [m_append: 3, m_concat: 2]

  alias Funx.Monad.Maybe
  alias Funx.Optics.Lens
  alias Funx.Optics.Prism
  alias Funx.Ord.Dsl.Executor
  alias Funx.Ord.Dsl.Parser

  # ============================================================================
  # DSL Macros
  # ============================================================================

  defmacro __using__(_opts) do
    quote do
      import Funx.Ord, only: [ord: 1]
    end
  end

  @doc """
  Creates an ordering from a block of projection specifications.

  Returns a `%Funx.Monoid.Ord{}` struct that can be used with `Funx.Ord`
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

      # With nested field paths
      ord do
        asc [:user, :profile, :created_at]
        desc [:user, :stats, :score]
      end
  """
  defmacro ord(do: block) do
    compile_ord(block, __CALLER__)
  end

  defp compile_ord(block, caller_env) do
    # Parse operations into Step structs
    steps = Parser.parse_operations(block, caller_env)

    # Execute (compile) steps to quoted AST
    Executor.execute_steps(steps)
  end

  # ============================================================================
  # Utility Functions
  # ============================================================================

  @doc """
  Transforms an ordering by applying a projection before comparison.

  ## Canonical Normalization Layer

  This function defines the **single normalization point** for all projections
  in the Ord DSL. Every projection type resolves to one of these four forms:

    * `Lens.t()` - Uses `view!/2` to extract the focused value (raises on missing)
    * `Prism.t()` - Uses `preview/2`, returns `Maybe`, with `Nothing < Just(_)` ordering
    * `{Prism.t(), or_else}` - Uses `preview/2`, falling back to `or_else` on `Nothing`
    * `(a -> b)` - Projection function applied directly

  All DSL syntax sugar (atoms, helpers, etc.) normalizes to these types in the parser.
  This function is the **only place** that converts optics to executable functions.

  The `ord` parameter may be an `Ord` module or a custom comparator map
  with `:lt?`, `:le?`, `:gt?`, and `:ge?` functions. The projection is applied
  to both inputs before invoking the underlying comparator.

  ## Examples

  Using a projection function:

      iex> ord = Funx.Ord.contramap(&String.length/1)
      iex> ord.lt?.("cat", "zebra")
      true
      iex> ord.gt?.("zebra", "cat")
      true

  Using a lens for single key access:

      iex> ord = Funx.Ord.contramap(Funx.Optics.Lens.key(:age))
      iex> ord.gt?.(%{age: 40}, %{age: 30})
      true
      iex> ord.lt?.(%{age: 30}, %{age: 40})
      true

  Using a bare prism (Nothing < Just):

      iex> prism = Funx.Optics.Prism.key(:score)
      iex> ord = Funx.Ord.contramap(prism)
      iex> ord.lt?.(%{}, %{score: 20})
      true
      iex> ord.gt?.(%{score: 30}, %{})
      true

  Using a prism with an or_else value:

      iex> prism = Funx.Optics.Prism.key(:score)
      iex> ord = Funx.Ord.contramap({prism, 0})
      iex> ord.lt?.(%{score: 10}, %{score: 20})
      true
      iex> ord.lt?.(%{}, %{score: 20})
      true
      iex> ord.gt?.(%{score: 30}, %{})
      true
  """

  @spec contramap(
          (a -> b) | Lens.t() | Prism.t() | {Prism.t(), b},
          ord_t()
        ) :: ord_map()
        when a: any, b: any
  def contramap(projection, ord \\ Funx.Ord.Protocol)

  # Lens
  def contramap(%Lens{} = lens, ord) do
    contramap(fn a -> Lens.view!(a, lens) end, ord)
  end

  # Bare Prism - uses Maybe.lift_ord (Nothing < Just)
  def contramap(%Prism{} = prism, ord) do
    contramap(fn a -> Prism.preview(a, prism) end, Maybe.lift_ord(ord))
  end

  # Prism with or_else
  def contramap({%Prism{} = prism, or_else}, ord) do
    contramap(
      fn a ->
        a |> Prism.preview(prism) |> Maybe.get_or_else(or_else)
      end,
      ord
    )
  end

  # Function
  def contramap(f, ord) when is_function(f, 1) do
    ord = to_ord_map(ord)

    %{
      lt?: fn a, b -> ord.lt?.(f.(a), f.(b)) end,
      le?: fn a, b -> ord.le?.(f.(a), f.(b)) end,
      gt?: fn a, b -> ord.gt?.(f.(a), f.(b)) end,
      ge?: fn a, b -> ord.ge?.(f.(a), f.(b)) end
    }
  end

  @doc """
  Returns the maximum of two values, with an optional custom `Ord`.

  ## Examples

      iex> Funx.Ord.max(3, 5)
      5

      iex> ord = Funx.Ord.contramap(&String.length/1, Funx.Ord.Protocol.Any)
      iex> Funx.Ord.max("cat", "zebra", ord)
      "zebra"
  """
  @spec max(a, a, ord_t()) :: a
        when a: any
  def max(a, b, ord \\ Funx.Ord.Protocol) do
    case compare(a, b, ord) do
      :lt -> b
      _ -> a
    end
  end

  @doc """
  Returns the minimum of two values, with an optional custom `Ord`.

  ## Examples

      iex> Funx.Ord.min(10, 7)
      7

      iex> ord = Funx.Ord.contramap(&String.length/1, Funx.Ord.Protocol.Any)
      iex> Funx.Ord.min("apple", "kiwi", ord)
      "kiwi"
  """
  @spec min(a, a, ord_t()) :: a
        when a: any
  def min(a, b, ord \\ Funx.Ord.Protocol) do
    case compare(a, b, ord) do
      :gt -> b
      _ -> a
    end
  end

  @doc """
  Clamps a value between `min` and `max`, with an optional custom `Ord`.

  ## Examples

      iex> Funx.Ord.clamp(5, 1, 10)
      5

      iex> Funx.Ord.clamp(0, 1, 10)
      1

      iex> Funx.Ord.clamp(15, 1, 10)
      10
  """
  @spec clamp(a, a, a, ord_t()) :: a
        when a: any
  def clamp(value, min, max, ord \\ Funx.Ord.Protocol) do
    value
    |> max(min, ord)
    |> min(max, ord)
  end

  @doc """
  Checks if `value` is between `min` and `max`, inclusive, with an optional custom `Ord`.

  ## Examples

      iex> Funx.Ord.between(5, 1, 10)
      true

      iex> Funx.Ord.between(0, 1, 10)
      false

      iex> Funx.Ord.between(11, 1, 10)
      false
  """
  @spec between(a, a, a, ord_t()) :: boolean()
        when a: any
  def between(value, min, max, ord \\ Funx.Ord.Protocol) do
    compare(value, min, ord) != :lt && compare(value, max, ord) != :gt
  end

  @doc """
  Compares two values and returns `:lt`, `:eq`, or `:gt`, with an optional custom `Ord`.

  ## Examples

      iex> Funx.Ord.compare(3, 5)
      :lt

      iex> Funx.Ord.compare(7, 7)
      :eq

      iex> Funx.Ord.compare(9, 4)
      :gt
  """
  @spec compare(a, a, ord_t()) :: :lt | :eq | :gt
        when a: any
  def compare(a, b, ord \\ Funx.Ord.Protocol) do
    ord = to_ord_map(ord)

    cond do
      ord.lt?.(a, b) -> :lt
      ord.gt?.(a, b) -> :gt
      true -> :eq
    end
  end

  @doc """
  Reverses the ordering logic.

  ## Examples

      iex> ord = Funx.Ord.reverse(Funx.Ord.Protocol.Any)
      iex> ord.lt?.(10, 5)
      true
  """
  @spec reverse(ord_t()) :: ord_map()
  def reverse(ord \\ Funx.Ord.Protocol) do
    ord = to_ord_map(ord)

    %{
      lt?: ord.gt?,
      le?: ord.ge?,
      gt?: ord.lt?,
      ge?: ord.le?
    }
  end

  @doc """
  Creates a comparator function from the given `Ord` module, returning `true`
  if `a` is less than or equal to `b` according to the module's ordering.

  Useful for sorting with `Enum.sort/2` or similar functions.

  ## Examples

      iex> comparator = Funx.Ord.comparator(Funx.Ord.Protocol.Any)
      iex> Enum.sort([3, 1, 2], comparator)
      [1, 2, 3]
  """
  @spec comparator(ord_t()) :: (any(), any() -> boolean())
  def comparator(ord_module) do
    fn a, b -> compare(a, b, ord_module) != :gt end
  end

  @doc """
  Converts an `Ord` instance into an equality comparator.

  This function creates a map containing two functions:
    - `eq?/2`: Returns `true` if `a` and `b` are considered equal by the given `Ord`.
    - `not_eq?/2`: Returns `true` if `a` and `b` are not considered equal by the given `Ord`.

  ## Examples

      iex> eq = Funx.Ord.to_eq(Funx.Ord.Protocol.Any)
      iex> eq.eq?.(5, 5)
      true
  """
  @spec to_eq(ord_t()) :: Funx.Eq.eq_map()
  def to_eq(ord \\ Funx.Ord.Protocol) do
    %{
      eq?: fn a, b -> compare(a, b, ord) == :eq end,
      not_eq?: fn a, b -> compare(a, b, ord) != :eq end
    }
  end

  @doc """
  Appends two `Ord` instances, combining their comparison logic.

  If the first `Ord` comparator determines an order, that result is used.
  If not, the second comparator is used as a fallback.

  ## Examples

      iex> ord1 = Funx.Ord.contramap(& &1.age, Funx.Ord.Protocol.Any)
      iex> ord2 = Funx.Ord.contramap(& &1.name, Funx.Ord.Protocol.Any)
      iex> combined = Funx.Ord.append(ord1, ord2)
      iex> combined.lt?.(%{age: 30, name: "Alice"}, %{age: 30, name: "Bob"})
      true
  """
  @spec append(Funx.Monoid.Ord.t(), Funx.Monoid.Ord.t()) :: Funx.Monoid.Ord.t()
  def append(a, b) do
    m_append(%Funx.Monoid.Ord{}, a, b)
  end

  @doc """
  Concatenates a list of `Ord` instances into a single composite comparator.

  This function reduces a list of `Ord` comparators into a single `Ord`,
  applying them in sequence until an order is determined.

  ## Examples

      iex> ord_list = [
      ...>   Funx.Ord.contramap(& &1.age, Funx.Ord.Protocol.Any),
      ...>   Funx.Ord.contramap(& &1.name, Funx.Ord.Protocol.Any)
      ...> ]
      iex> combined = Funx.Ord.concat(ord_list)
      iex> combined.gt?.(%{age: 25, name: "Charlie"}, %{age: 25, name: "Bob"})
      true
  """
  @spec concat([Funx.Monoid.Ord.t()]) :: Funx.Monoid.Ord.t()
  def concat(ord_list) when is_list(ord_list) do
    m_concat(%Funx.Monoid.Ord{}, ord_list)
  end

  def to_ord_map(%{lt?: lt_fun, le?: le_fun, gt?: gt_fun, ge?: ge_fun} = ord_map)
      when is_function(lt_fun, 2) and
             is_function(le_fun, 2) and
             is_function(gt_fun, 2) and
             is_function(ge_fun, 2),
      do: ord_map

  def to_ord_map(module) when is_atom(module) do
    %{
      lt?: &module.lt?/2,
      le?: &module.le?/2,
      gt?: &module.gt?/2,
      ge?: &module.ge?/2
    }
  end
end
