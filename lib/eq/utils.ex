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
  alias Funx.Monoid
  alias Funx.Optics.Lens

  @doc """
  Transforms an equality check by applying a projection before comparison.

  The `projection` can take several forms:

    * a function `(a -> b)`
      The projection is applied directly.

    * a `Lens`
      The lens’s `get/2` function is used as the projection, meaning the
      structure is passed as the first argument and the lens as the second.

    * an atom
      Treated as a key and converted into a lens with `Lens.key/1`.

    * a list of keys
      Treated as a nested path and converted into a lens with `Lens.path/1`.

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

  Using a key (automatically lifted into a lens):

      iex> eq = Funx.Eq.Utils.contramap(:age)
      iex> eq.eq?.(%{age: 40}, %{age: 40})
      true

  Using a path (nested access):

      iex> eq = Funx.Eq.Utils.contramap([:stats, :wins])
      iex> eq.eq?.(%{stats: %{wins: 2}}, %{stats: %{wins: 2}})
      true

  Using a lens explicitly:

      iex> lens = Funx.Optics.Lens.key!(:score)
      iex> eq = Funx.Eq.Utils.contramap(lens)
      iex> eq.eq?.(%{score: 10}, %{score: 10})
      true
  """

  @spec contramap(
          (a -> b)
          | Lens.t()
          | atom
          | [term],
          eq_t()
        ) :: eq_map()
        when a: any, b: any
  def contramap(projection, eq \\ Eq)

  # Lens
  def contramap(%Lens{} = lens, eq) do
    contramap(fn a -> Lens.view!(a, lens) end, eq)
  end

  # Atom key → lens
  def contramap(key, eq) when is_atom(key) do
    lens = Lens.key!(key)
    contramap(lens, eq)
  end

  # Path → lens
  def contramap(path, eq) when is_list(path) do
    lens = Lens.path(path)
    contramap(lens, eq)
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

  The `projection` may be:

    * a function `(a -> b)`
      Applied directly to each value.

    * a `Funx.Optics.Lens`
      Its `get/2` function is used as the projection.

    * an atom
      Treated as a key and converted into a lens with `Lens.key/1`.

    * a list of keys
      Treated as a nested path and converted into a lens with `Lens.path/1`.

  The `eq` parameter may be an `Eq` module or a custom comparator map.
  The projection is applied to both arguments before invoking the comparator.

  ## Examples

  Using a projection function:

      iex> Funx.Eq.Utils.eq_by?(& &1.age, %{age: 30}, %{age: 30})
      true
      iex> Funx.Eq.Utils.eq_by?(& &1.age, %{age: 30}, %{age: 25})
      false

  Using a key (auto-lensed):

      iex> Funx.Eq.Utils.eq_by?(:age, %{age: 40}, %{age: 40})
      true

  Using a nested path:

      iex> Funx.Eq.Utils.eq_by?([:stats, :wins], %{stats: %{wins: 2}}, %{stats: %{wins: 2}})
      true

  Using a lens explicitly:

      iex> lens = Funx.Optics.Lens.key!(:score)
      iex> Funx.Eq.Utils.eq_by?(lens, %{score: 10}, %{score: 10})
      true
  """
  @spec eq_by?(
          (a -> b)
          | Lens.t()
          | atom
          | [term],
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

  # Atom key → lens
  def eq_by?(key, a, b, eq) when is_atom(key) do
    lens = Lens.key!(key)
    eq_by?(lens, a, b, eq)
  end

  # Path → lens
  def eq_by?(path, a, b, eq) when is_list(path) do
    lens = Lens.path(path)
    eq_by?(lens, a, b, eq)
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
