defmodule Funx.Eq do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Feq%2Feq.livemd)

  Utilities and DSL for working with the `Funx.Eq.Protocol`.

  This module provides two main capabilities:

  1. **Utility functions** for working with equality comparisons:
     - `contramap/2` - Transform equality checks via projections
     - `eq?/3`, `not_eq?/3` - Direct equality checks
     - `append_all/2`, `append_any/2` - Combine comparators
     - `concat_all/1`, `concat_any/1` - Combine lists of comparators
     - `to_predicate/2` - Convert to single-argument predicates

  2. **Declarative DSL** for building complex equality comparators:
     - `eq do ... end` - Build comparators with clean syntax
     - Supports `on`, `diff_on`, `any`, and `all` directives
     - Compiles at compile-time for efficiency

  These functions assume that types passed in either support Elixir's equality operator
  or implement the `Funx.Eq.Protocol` protocol.

  ## DSL Usage

      use Funx.Eq

      eq do
        on :name
        on :age
      end

  ## Utility Usage

      Funx.Eq.contramap(&(&1.age))
      Funx.Eq.eq?(value1, value2)

  For detailed DSL documentation, see the `eq/1` macro below.
  """

  @type eq_map() :: %{
          eq?: (any(), any() -> boolean()),
          not_eq?: (any(), any() -> boolean())
        }

  @type eq_t() :: Funx.Eq.Protocol.t() | eq_map()

  import Funx.Monoid.Utils, only: [m_append: 3, m_concat: 2]
  alias Funx.Eq.Dsl.Executor
  alias Funx.Eq.Dsl.Parser
  alias Funx.Monad.Maybe
  alias Funx.Monoid
  alias Funx.Optics.Lens
  alias Funx.Optics.Prism
  alias Funx.Optics.Traversal

  # ============================================================================
  # DSL Macros
  # ============================================================================

  defmacro __using__(_opts) do
    quote do
      import Funx.Eq, only: [eq: 1]
    end
  end

  @doc """
  Creates an equality comparator from a block of projection specifications.

  Returns a `%Funx.Monoid.Eq.All{}` struct that can be used with `Funx.Eq`
  functions like `eq?/3`, `not_eq?/3`, or `to_predicate/2`.

  ## Directives

    - `on` - Field/projection must be equal
    - `diff_on` - Field/projection must be different
    - `any` - At least one nested check must pass (OR logic)
    - `all` - All nested checks must pass (AND logic, implicit at top level)

  ## Projection Types

  The DSL supports the same projection forms as Ord DSL:

    - Atom - Field access via `Prism.key(atom)`
    - Atom with or_else - Optional field via `{Prism.key(atom), or_else}`
    - Function - Direct projection `fn x -> ... end` or `&fun/1`
    - Lens - Explicit lens for nested access (raises on missing)
    - Prism - Explicit prism for optional fields
    - Prism with or_else - `{Prism.t(), or_else}` for optional with fallback
    - Behaviour - Custom equality via `c:Funx.Eq.Dsl.Behaviour.eq/1`

  ## Equivalence Relations and diff_on

  **Core Eq** (using only `on`, `all`, `any`) forms an equivalence relation with three properties:

    - **Reflexive**: `eq?(a, a)` is always true
    - **Symmetric**: If `eq?(a, b)` then `eq?(b, a)`
    - **Transitive**: If `eq?(a, b)` and `eq?(b, c)` then `eq?(a, c)`

  These properties guarantee that Core Eq partitions values into equivalence classes, making it
  safe for use with Enum.uniq/2, MapSet, and grouping operations.

  **Extended Eq** (using `diff_on`) expresses boolean equality predicates and does not guarantee transitivity.

  **Important**: If you need equivalence classes (grouping, uniq, set membership), do not use `diff_on`.

  ## Examples

  Basic multi-field equality:

      use Funx.Eq

      eq_person = eq do
        on :name
        on :age
      end

  Using diff_on to check difference:

      eq_same_person = eq do
        on :name
        on :email
        diff_on :id
      end

  Nested any blocks (OR logic):

      eq_contact = eq do
        any do
          on :email
          on :username
        end
      end

  Mixed composition:

      eq_mixed = eq do
        on :department
        any do
          on :email
          on :username
        end
      end

  With nested field paths:

      eq_nested = eq do
        on [:user, :profile, :name]
        on [:user, :profile, :age]
      end
  """
  defmacro eq(do: block) do
    compile_eq(block, __CALLER__)
  end

  defp compile_eq(block, caller_env) do
    nodes = Parser.parse_operations(block, caller_env)
    Executor.execute_nodes(nodes)
  end

  # ============================================================================
  # Utility Functions
  # ============================================================================

  @doc """
  Transforms an equality check by applying a projection before comparison.

  The `projection` must be one of:

    * a function `(a -> b)` - Applied directly to extract the comparison value
    * a `Lens` - Uses `view!/2` to extract the focused value (raises on missing)
    * a `Prism` - Uses `preview/2` (Nothing == Nothing)
    * a tuple `{Prism, default}` - Uses `preview/2`, falling back to `default` on `Nothing`
    * a `Traversal` - Uses `to_list_maybe/2`, compares all foci element-by-element (both must have all foci)

  The `eq` parameter may be an `Eq` module or a custom comparator map
  with `:eq?` and `:not_eq?` functions. The projection is applied to both
  inputs before invoking the underlying comparator.

  ## Examples

  Using a projection function:

      iex> eq = Funx.Eq.contramap(& &1.age)
      iex> eq.eq?.(%{age: 30}, %{age: 30})
      true
      iex> eq.eq?.(%{age: 30}, %{age: 25})
      false

  Using a lens for single key access:

      iex> eq = Funx.Eq.contramap(Funx.Optics.Lens.key(:age))
      iex> eq.eq?.(%{age: 40}, %{age: 40})
      true

  Using a prism with a default value:

      iex> prism = Funx.Optics.Prism.key(:score)
      iex> eq = Funx.Eq.contramap({prism, 0})
      iex> eq.eq?.(%{score: 10}, %{score: 10})
      true
      iex> eq.eq?.(%{}, %{score: 0})
      true
  """

  @spec contramap(
          (a -> b) | Lens.t() | Prism.t() | {Prism.t(), b} | Traversal.t(),
          eq_t()
        ) :: eq_map()
        when a: any, b: any
  def contramap(projection, eq \\ Funx.Eq.Protocol)

  # Lens
  def contramap(%Lens{} = lens, eq) do
    contramap(fn a -> Lens.view!(a, lens) end, eq)
  end

  # Bare Prism - lift eq over Maybe
  def contramap(%Prism{} = prism, eq) do
    contramap(fn a -> Prism.preview(a, prism) end, Maybe.lift_eq(eq))
  end

  # Prism with default
  def contramap({%Prism{} = prism, default}, eq) do
    contramap(
      fn a ->
        a |> Prism.preview(prism) |> Maybe.get_or_else(default)
      end,
      eq
    )
  end

  # Traversal (both must have all foci)
  def contramap(%Traversal{} = traversal, eq) do
    list_eq = list_eq(eq)

    %{
      eq?: fn a, b ->
        case {Traversal.to_list_maybe(a, traversal), Traversal.to_list_maybe(b, traversal)} do
          {%Maybe.Just{value: list_a}, %Maybe.Just{value: list_b}} ->
            list_eq.eq?.(list_a, list_b)

          _ ->
            false
        end
      end,
      not_eq?: fn a, b ->
        case {Traversal.to_list_maybe(a, traversal), Traversal.to_list_maybe(b, traversal)} do
          {%Maybe.Just{value: list_a}, %Maybe.Just{value: list_b}} ->
            list_eq.not_eq?.(list_a, list_b)

          _ ->
            true
        end
      end
    }
  end

  # Function
  def contramap(f, eq) when is_function(f, 1) do
    eq = to_eq_map(eq)

    %{
      eq?: fn a, b -> eq.eq?.(f.(a), f.(b)) end,
      not_eq?: fn a, b -> eq.not_eq?.(f.(a), f.(b)) end
    }
  end

  @doc """
  Converts an Eq DSL result or projection to an eq_map.

  If passed a plain map with `eq?/2` and `not_eq?/2` functions (the result
  of `eq do ... end`), returns it directly. Otherwise, delegates to `contramap/2`.

  Used internally by `Funx.Macros.eq_for/3` to support both projection-based
  and DSL-based equality definitions.
  """
  @spec to_eq_map_or_contramap(any(), eq_t()) :: eq_map()
  # Plain map with eq?/not_eq? keys (DSL result)
  def to_eq_map_or_contramap(%{eq?: eq?, not_eq?: not_eq?} = map, _eq)
      when is_function(eq?, 2) and is_function(not_eq?, 2) and not is_struct(map) do
    map
  end

  def to_eq_map_or_contramap(projection, eq) do
    contramap(projection, eq)
  end

  @doc """
  Checks equality of two values by applying a projection before comparison.

  The `projection` must be one of:

    * a function `(a -> b)` - Applied directly to extract the comparison value
    * a `Lens` - Uses `view!/2` to extract the focused value (raises on missing)
    * a tuple `{Prism, default}` - Uses `preview/2`, falling back to `default` on `Nothing`

  The `eq` parameter may be an `Eq` module or a custom comparator map.
  The projection is applied to both arguments before invoking the comparator.

  ## Examples

  Using a projection function:

      iex> Funx.Eq.eq_by?(& &1.age, %{age: 30}, %{age: 30})
      true
      iex> Funx.Eq.eq_by?(& &1.age, %{age: 30}, %{age: 25})
      false

  Using a lens for single key access:

      iex> Funx.Eq.eq_by?(Funx.Optics.Lens.key(:age), %{age: 40}, %{age: 40})
      true

  Using a prism with a default value:

      iex> prism = Funx.Optics.Prism.key(:score)
      iex> Funx.Eq.eq_by?({prism, 0}, %{score: 10}, %{score: 10})
      true
      iex> Funx.Eq.eq_by?({prism, 0}, %{}, %{score: 0})
      true
  """
  @spec eq_by?(
          (a -> b) | Lens.t() | {Prism.t(), b},
          a,
          a,
          eq_t()
        ) :: boolean()
        when a: any, b: any
  def eq_by?(projection, a, b, eq \\ Funx.Eq.Protocol)

  # Lens
  def eq_by?(%Lens{} = lens, a, b, eq) do
    eq_by?(fn x -> Lens.view!(x, lens) end, a, b, eq)
  end

  # Prism with default
  def eq_by?({%Prism{} = prism, default}, a, b, eq) do
    eq_by?(
      fn x ->
        x |> Prism.preview(prism) |> Maybe.get_or_else(default)
      end,
      a,
      b,
      eq
    )
  end

  # Function
  def eq_by?(f, a, b, eq) when is_function(f, 1) do
    eq = to_eq_map(eq)
    eq.eq?.(f.(a), f.(b))
  end

  @doc """
  Returns true if two values are equal, using a specified or default `Eq`.

  This function compares the values *directly*, without applying any projection.
  For comparisons that require projecting or focusing on part of a structure,
  use `Funx.Eq.eq_by?/4` or `Funx.Eq.contramap/2`.

  ## Examples

      iex> Funx.Eq.eq?(42, 42)
      true
      iex> Funx.Eq.eq?("foo", "bar")
      false
  """
  @spec eq?(a, a, eq_t()) :: boolean()
        when a: any
  def eq?(a, b, eq \\ Funx.Eq.Protocol) do
    eq = to_eq_map(eq)
    eq.eq?.(a, b)
  end

  @doc """
  Returns false if two values are not equal, using a specified or default `Eq`.

  This function compares the values directly, without applying any projection.
  For comparisons based on a projection, lens, key, or path,
  use `Funx.Eq.eq_by?/4` or a comparator produced by `Funx.Eq.contramap/2`.

  ## Examples

      iex> Funx.Eq.not_eq?(42, 99)
      true
      iex> Funx.Eq.not_eq?("foo", "foo")
      false
  """
  @spec not_eq?(a, a, eq_t()) :: boolean()
        when a: any
  def not_eq?(a, b, eq \\ Funx.Eq.Protocol) do
    eq = to_eq_map(eq)
    eq.not_eq?.(a, b)
  end

  @doc """
  Combines two equality comparators using the `Eq.All` monoid.

  This function merges two equality comparisons, requiring **both** to return `true`
  for the final result to be considered equal. This enforces a **strict** equality rule,
  where all comparators must agree.

  ## Examples

      iex> eq1 = Funx.Eq.contramap(& &1.name)
      iex> eq2 = Funx.Eq.contramap(& &1.age)
      iex> combined = Funx.Eq.append_all(eq1, eq2)
      iex> Funx.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 30}, combined)
      true
      iex> Funx.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      false
  """
  @spec append_all(eq_t(), eq_t()) :: eq_t()
  def append_all(a, b) do
    m_append(%Monoid.Eq.All{}, a, b)
  end

  @doc """
  Combines two equality comparators using the `Eq.Any` monoid.

  This function merges two equality comparisons, where **at least one**
  must return `true` for the final result to be considered equal.

  ## Examples

      iex> eq1 = Funx.Eq.contramap(& &1.name)
      iex> eq2 = Funx.Eq.contramap(& &1.age)
      iex> combined = Funx.Eq.append_any(eq1, eq2)
      iex> Funx.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      true
      iex> Funx.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Bob", age: 25}, combined)
      false
  """
  @spec append_any(eq_t(), eq_t()) :: eq_t()
  def append_any(a, b) do
    m_append(%Monoid.Eq.Any{}, a, b)
  end

  @doc """
  Concatenates a list of equality comparators using the `Eq.All` monoid.

  The resulting comparator requires **all** comparators in the list to agree
  that two values are equal.

  ## Examples

      iex> eq1 = Funx.Eq.contramap(& &1.name)
      iex> eq2 = Funx.Eq.contramap(& &1.age)
      iex> combined = Funx.Eq.concat_all([eq1, eq2])
      iex> Funx.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 30}, combined)
      true
      iex> Funx.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      false
  """
  @spec concat_all([eq_t()]) :: eq_t()
  def concat_all(eq_list) when is_list(eq_list) do
    m_concat(%Monoid.Eq.All{}, eq_list)
  end

  @doc """
  Concatenates a list of equality comparators using the `Eq.Any` monoid.

  The resulting comparator allows **any** comparator in the list to determine
  equality, making it more permissive.

  ## Examples

      iex> eq1 = Funx.Eq.contramap(& &1.name)
      iex> eq2 = Funx.Eq.contramap(& &1.age)
      iex> combined = Funx.Eq.concat_any([eq1, eq2])
      iex> Funx.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      true
      iex> Funx.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Bob", age: 25}, combined)
      false
  """
  @spec concat_any([eq_t()]) :: eq_t()
  def concat_any(eq_list) when is_list(eq_list) do
    m_concat(%Monoid.Eq.Any{}, eq_list)
  end

  @doc """
  Converts an `Eq` comparator into a single-argument predicate function for use in `Enum` functions.

  The resulting predicate takes a single element and returns `true` if it matches the `target`
  based on the specified `Eq`. If no custom `Eq` is provided, it defaults to `Funx.Eq.Protocol`.

  ## Examples

      iex> eq = Funx.Eq.contramap(& &1.name)
      iex> predicate = Funx.Eq.to_predicate(%{name: "Alice"}, eq)
      iex> Funx.Filterable.filter([%{name: "Alice"}, %{name: "Bob"}], predicate)
      [%{name: "Alice"}]
  """
  @spec to_predicate(a, eq_t()) :: (a -> boolean())
        when a: any
  def to_predicate(target, eq \\ Funx.Eq.Protocol) do
    eq = to_eq_map(eq)

    fn elem -> eq.eq?.(elem, target) end
  end

  # Private helper: creates an eq for comparing lists element-wise
  defp list_eq(eq) do
    eq = to_eq_map(eq)

    %{
      eq?: fn list_a, list_b ->
        length(list_a) == length(list_b) and
          Enum.zip(list_a, list_b)
          |> Enum.all?(fn {va, vb} -> eq.eq?.(va, vb) end)
      end,
      not_eq?: fn list_a, list_b ->
        length(list_a) != length(list_b) or
          Enum.zip(list_a, list_b)
          |> Enum.any?(fn {va, vb} -> eq.not_eq?.(va, vb) end)
      end
    }
  end

  def to_eq_map(%{eq?: eq_fun, not_eq?: not_eq_fun} = eq_map)
      when is_function(eq_fun, 2) and is_function(not_eq_fun, 2) do
    eq_map
  end

  def to_eq_map(module) when is_atom(module) do
    # Check if it implements the protocol or has eq?/2 directly
    if function_exported?(module, :eq?, 2) do
      # Module has eq?/2 directly (Eq.Protocol module)
      %{
        eq?: &module.eq?/2,
        not_eq?: &module.not_eq?/2
      }
    else
      # Use the protocol (for structs implementing Funx.Eq.Protocol protocol)
      %{
        eq?: &Funx.Eq.Protocol.eq?/2,
        not_eq?: &Funx.Eq.Protocol.not_eq?/2
      }
    end
  end
end
