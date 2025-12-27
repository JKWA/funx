defmodule Funx.Eq.Utils do
  @moduledoc """
  Utility functions for working with the `Funx.Eq` protocol.
  These functions assume that types passed in either support Elixir's equality operator
  or implement the `Funx.Eq` protocol.
  """

  @type eq_map() :: %{
          eq?: (any(), any() -> boolean()),
          not_eq?: (any(), any() -> boolean())
        }

  @type eq_t() :: Funx.Eq.t() | eq_map()

  import Funx.Monoid.Utils, only: [m_append: 3, m_concat: 2]
  alias Funx.Eq
  alias Funx.Monad.Maybe
  alias Funx.Monoid
  alias Funx.Optics.Lens
  alias Funx.Optics.Prism
  alias Funx.Optics.Traversal

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

      iex> eq = Funx.Eq.Utils.contramap(& &1.age)
      iex> eq.eq?.(%{age: 30}, %{age: 30})
      true
      iex> eq.eq?.(%{age: 30}, %{age: 25})
      false

  Using a lens for single key access:

      iex> eq = Funx.Eq.Utils.contramap(Funx.Optics.Lens.key(:age))
      iex> eq.eq?.(%{age: 40}, %{age: 40})
      true

  Using a prism with a default value:

      iex> prism = Funx.Optics.Prism.key(:score)
      iex> eq = Funx.Eq.Utils.contramap({prism, 0})
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
  def contramap(projection, eq \\ Eq)

  # Lens
  def contramap(%Lens{} = lens, eq) do
    contramap(fn a -> Lens.view!(a, lens) end, eq)
  end

  # Bare Prism (Nothing == Nothing)
  def contramap(%Prism{} = prism, eq) do
    eq = to_eq_map(eq)

    %{
      eq?: fn a, b ->
        case {Prism.preview(a, prism), Prism.preview(b, prism)} do
          {%Maybe.Nothing{}, %Maybe.Nothing{}} -> true
          {%Maybe.Just{value: va}, %Maybe.Just{value: vb}} -> eq.eq?.(va, vb)
          _ -> false
        end
      end,
      not_eq?: fn a, b ->
        case {Prism.preview(a, prism), Prism.preview(b, prism)} do
          {%Maybe.Nothing{}, %Maybe.Nothing{}} -> false
          {%Maybe.Just{value: va}, %Maybe.Just{value: vb}} -> eq.not_eq?.(va, vb)
          _ -> true
        end
      end
    }
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
    eq = to_eq_map(eq)

    %{
      eq?: fn a, b ->
        case {Traversal.to_list_maybe(a, traversal), Traversal.to_list_maybe(b, traversal)} do
          {%Maybe.Just{value: list_a}, %Maybe.Just{value: list_b}} ->
            Enum.zip(list_a, list_b)
            |> Enum.all?(fn {va, vb} -> eq.eq?.(va, vb) end)

          _ ->
            false
        end
      end,
      not_eq?: fn a, b ->
        case {Traversal.to_list_maybe(a, traversal), Traversal.to_list_maybe(b, traversal)} do
          {%Maybe.Just{value: list_a}, %Maybe.Just{value: list_b}} ->
            Enum.zip(list_a, list_b)
            |> Enum.any?(fn {va, vb} -> eq.not_eq?.(va, vb) end)

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
  Checks equality of two values by applying a projection before comparison.

  The `projection` must be one of:

    * a function `(a -> b)` - Applied directly to extract the comparison value
    * a `Lens` - Uses `view!/2` to extract the focused value (raises on missing)
    * a tuple `{Prism, default}` - Uses `preview/2`, falling back to `default` on `Nothing`

  The `eq` parameter may be an `Eq` module or a custom comparator map.
  The projection is applied to both arguments before invoking the comparator.

  ## Examples

  Using a projection function:

      iex> Funx.Eq.Utils.eq_by?(& &1.age, %{age: 30}, %{age: 30})
      true
      iex> Funx.Eq.Utils.eq_by?(& &1.age, %{age: 30}, %{age: 25})
      false

  Using a lens for single key access:

      iex> Funx.Eq.Utils.eq_by?(Funx.Optics.Lens.key(:age), %{age: 40}, %{age: 40})
      true

  Using a prism with a default value:

      iex> prism = Funx.Optics.Prism.key(:score)
      iex> Funx.Eq.Utils.eq_by?({prism, 0}, %{score: 10}, %{score: 10})
      true
      iex> Funx.Eq.Utils.eq_by?({prism, 0}, %{}, %{score: 0})
      true
  """
  @spec eq_by?(
          (a -> b) | Lens.t() | {Prism.t(), b},
          a,
          a,
          eq_t()
        ) :: boolean()
        when a: any, b: any
  def eq_by?(projection, a, b, eq \\ Eq)

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
  use `Funx.Eq.Utils.eq_by?/4` or `Funx.Eq.Utils.contramap/2`.

  ## Examples

      iex> Funx.Eq.Utils.eq?(42, 42)
      true
      iex> Funx.Eq.Utils.eq?("foo", "bar")
      false
  """
  @spec eq?(a, a, eq_t()) :: boolean()
        when a: any
  def eq?(a, b, eq \\ Eq) do
    eq = to_eq_map(eq)
    eq.eq?.(a, b)
  end

  @doc """
  Returns false if two values are not equal, using a specified or default `Eq`.

  This function compares the values directly, without applying any projection.
  For comparisons based on a projection, lens, key, or path,
  use `Funx.Eq.Utils.eq_by?/4` or a comparator produced by `Funx.Eq.Utils.contramap/2`.

  ## Examples

      iex> Funx.Eq.Utils.not_eq?(42, 99)
      true
      iex> Funx.Eq.Utils.not_eq?("foo", "foo")
      false
  """
  @spec not_eq?(a, a, eq_t()) :: boolean()
        when a: any
  def not_eq?(a, b, eq \\ Eq) do
    eq = to_eq_map(eq)
    eq.not_eq?.(a, b)
  end

  @doc """
  Combines two equality comparators using the `Eq.All` monoid.

  This function merges two equality comparisons, requiring **both** to return `true`
  for the final result to be considered equal. This enforces a **strict** equality rule,
  where all comparators must agree.

  ## Examples

      iex> eq1 = Funx.Eq.Utils.contramap(& &1.name)
      iex> eq2 = Funx.Eq.Utils.contramap(& &1.age)
      iex> combined = Funx.Eq.Utils.append_all(eq1, eq2)
      iex> Funx.Eq.Utils.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 30}, combined)
      true
      iex> Funx.Eq.Utils.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      false
  """
  @spec append_all(Monoid.Eq.All.t(), Monoid.Eq.All.t()) :: Monoid.Eq.All.t()
  def append_all(a, b) do
    m_append(%Monoid.Eq.All{}, a, b)
  end

  @doc """
  Combines two equality comparators using the `Eq.Any` monoid.

  This function merges two equality comparisons, where **at least one**
  must return `true` for the final result to be considered equal.

  ## Examples

      iex> eq1 = Funx.Eq.Utils.contramap(& &1.name)
      iex> eq2 = Funx.Eq.Utils.contramap(& &1.age)
      iex> combined = Funx.Eq.Utils.append_any(eq1, eq2)
      iex> Funx.Eq.Utils.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      true
      iex> Funx.Eq.Utils.eq?(%{name: "Alice", age: 30}, %{name: "Bob", age: 25}, combined)
      false
  """
  @spec append_any(Monoid.Eq.Any.t(), Monoid.Eq.Any.t()) :: Monoid.Eq.Any.t()
  def append_any(a, b) do
    m_append(%Monoid.Eq.Any{}, a, b)
  end

  @doc """
  Concatenates a list of equality comparators using the `Eq.All` monoid.

  The resulting comparator requires **all** comparators in the list to agree
  that two values are equal.

  ## Examples

      iex> eq1 = Funx.Eq.Utils.contramap(& &1.name)
      iex> eq2 = Funx.Eq.Utils.contramap(& &1.age)
      iex> combined = Funx.Eq.Utils.concat_all([eq1, eq2])
      iex> Funx.Eq.Utils.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 30}, combined)
      true
      iex> Funx.Eq.Utils.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      false
  """
  @spec concat_all([Monoid.Eq.All.t()]) :: Monoid.Eq.All.t()
  def concat_all(eq_list) when is_list(eq_list) do
    m_concat(%Monoid.Eq.All{}, eq_list)
  end

  @doc """
  Concatenates a list of equality comparators using the `Eq.Any` monoid.

  The resulting comparator allows **any** comparator in the list to determine
  equality, making it more permissive.

  ## Examples

      iex> eq1 = Funx.Eq.Utils.contramap(& &1.name)
      iex> eq2 = Funx.Eq.Utils.contramap(& &1.age)
      iex> combined = Funx.Eq.Utils.concat_any([eq1, eq2])
      iex> Funx.Eq.Utils.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      true
      iex> Funx.Eq.Utils.eq?(%{name: "Alice", age: 30}, %{name: "Bob", age: 25}, combined)
      false
  """
  @spec concat_any([Monoid.Eq.Any.t()]) :: Monoid.Eq.Any.t()
  def concat_any(eq_list) when is_list(eq_list) do
    m_concat(%Monoid.Eq.Any{}, eq_list)
  end

  @doc """
  Converts an `Eq` comparator into a single-argument predicate function for use in `Enum` functions.

  The resulting predicate takes a single element and returns `true` if it matches the `target`
  based on the specified `Eq`. If no custom `Eq` is provided, it defaults to `Funx.Eq`.

  ## Examples

      iex> eq = Funx.Eq.Utils.contramap(& &1.name)
      iex> predicate = Funx.Eq.Utils.to_predicate(%{name: "Alice"}, eq)
      iex> Funx.Filterable.filter([%{name: "Alice"}, %{name: "Bob"}], predicate)
      [%{name: "Alice"}]
  """
  @spec to_predicate(a, eq_t()) :: (a -> boolean())
        when a: any
  def to_predicate(target, eq \\ Eq) do
    eq = to_eq_map(eq)

    fn elem -> eq.eq?.(elem, target) end
  end

  def to_eq_map(%{eq?: eq_fun, not_eq?: not_eq_fun} = eq_map)
      when is_function(eq_fun, 2) and is_function(not_eq_fun, 2) do
    eq_map
  end

  def to_eq_map(module) when is_atom(module) do
    %{
      eq?: &module.eq?/2,
      not_eq?: &module.not_eq?/2
    }
  end
end
