defmodule Monex.Eq.Utils do
  @moduledoc """
  Utility functions for working with the `Monex.Eq` protocol.
  These functions assume that types passed in either support Elixir's equality operator
  or implement the `Monex.Eq` protocol.
  """

  @type eq_map() :: %{
          eq?: (any(), any() -> boolean()),
          not_eq?: (any(), any() -> boolean())
        }

  alias Monex.Eq
  alias Monex.Monoid

  @doc """
  Transforms an equality check by applying a function `f` to values before comparison.

  The `eq` parameter can be an `Eq` module or a custom comparator map with an `:eq?` function.
  If an `Eq` module is provided, it wraps the module’s function to apply `f` to each value before invoking the equality check.
  If a custom comparator map is provided, it wraps the function in the map to apply `f` to each value.
  """
  def contramap(f, module) when is_atom(module) do
    %{
      eq?: fn a, b -> module.eq?(f.(a), f.(b)) end,
      not_eq?: fn a, b -> module.not_eq?(f.(a), f.(b)) end
    }
  end

  def contramap(f, %{} = custom_map) do
    %{
      eq?: fn a, b -> custom_map[:eq?].(f.(a), f.(b)) end,
      not_eq?: fn a, b -> custom_map[:not_eq?].(f.(a), f.(b)) end
    }
  end

  def contramap(f), do: contramap(f, Eq)

  @doc """
  Checks equality of values by applying a projection function, using a specified or default `Eq`.

  The `eq` parameter can be an `Eq` module or a custom comparator map with an `:eq?` function.
  """
  def eq_by?(f, a, b, module) when is_atom(module) do
    module.eq?(f.(a), f.(b))
  end

  def eq_by?(f, a, b, %{} = custom_map) do
    custom_map[:eq?].(f.(a), f.(b))
  end

  def eq_by?(f, a, b), do: eq_by?(f, a, b, Eq)

  @doc """
  Returns true if two values are equal, using a specified or default `Eq`.
  """
  def eq?(a, b, module) when is_atom(module) do
    module.eq?(a, b)
  end

  def eq?(a, b, %{} = custom_map) do
    custom_map[:eq?].(a, b)
  end

  def eq?(a, b), do: eq?(a, b, Eq)

  @doc """
  Returns false if two values are not equal, using a specified or default `Eq`.
  """
  def not_eq?(a, b, module) when is_atom(module) do
    module.not_eq?(a, b)
  end

  def not_eq?(a, b, %{} = custom_map) do
    custom_map[:not_eq?].(a, b)
  end

  def not_eq?(a, b), do: not_eq?(a, b, Eq)

  @doc """
  Combines two equality comparators using the `Eq.All` monoid.

  This function merges two equality comparisons, requiring **both** to return `true`
  for the final result to be considered equal. This enforces a **strict** equality rule,
  where all comparators must agree.

  ## Examples

      iex> eq1 = Monex.Eq.Utils.contramap(& &1.name)
      iex> eq2 = Monex.Eq.Utils.contramap(& &1.age)
      iex> combined = append_all(eq1, eq2)
      iex> Monex.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 30}, combined)
      true
      iex> Monex.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      false

  """
  def append_all(a, b) do
    Monoid.Utils.append(%Monoid.Eq.All{}, a, b)
  end

  @doc """
  Combines two equality comparators using the `Eq.Any` monoid.

  This function merges two equality comparisons, where **at least one**
  must return `true` for the final result to be considered equal. This
  allows for a **looser** equality rule where satisfying any comparator
  is sufficient.

  ## Examples

      iex> eq1 = Monex.Eq.Utils.contramap(& &1.name)
      iex> eq2 = Monex.Eq.Utils.contramap(& &1.age)
      iex> combined = append_any(eq1, eq2)
      iex> Monex.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      true
      iex> Monex.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Bob", age: 25}, combined)
      false

  """
  def append_any(a, b) do
    Monoid.Utils.append(%Monoid.Eq.Any{}, a, b)
  end

  @doc """
  Concatenates a list of equality comparators using the `Eq.All` monoid.

  The resulting comparator requires **all** comparators in the list to agree
  that two values are equal.

  ## Examples

      iex> eq1 = Monex.Eq.Utils.contramap(& &1.name)
      iex> eq2 = Monex.Eq.Utils.contramap(& &1.age)
      iex> combined = concat_all([eq1, eq2])
      iex> Monex.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 30}, combined)
      true
      iex> Monex.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      false

  """
  def concat_all(eq_list) when is_list(eq_list) do
    Monoid.Utils.concat(%Monoid.Eq.All{}, eq_list)
  end

  @doc """
  Concatenates a list of equality comparators using the `Eq.Any` monoid.

  The resulting comparator allows **any** comparator in the list to determine
  equality, making it more permissive.

  ## Examples

      iex> eq1 = Monex.Eq.Utils.contramap(& &1.name)
      iex> eq2 = Monex.Eq.Utils.contramap(& &1.age)
      iex> combined = concat_any([eq1, eq2])
      iex> Monex.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Alice", age: 25}, combined)
      true
      iex> Monex.Eq.eq?(%{name: "Alice", age: 30}, %{name: "Bob", age: 25}, combined)
      false

  """
  def concat_any(eq_list) when is_list(eq_list) do
    Monoid.Utils.concat(%Monoid.Eq.Any{}, eq_list)
  end

  @doc """
  Converts an `Eq` comparator into a single-argument predicate function for use in `Enum` functions.

  The resulting predicate takes a single element and returns `true` if it matches the `target`
  based on the specified `Eq`. If no custom `Eq` is provided, it defaults to `Monex.Eq`.
  """
  @spec to_predicate(any(), module() | map()) :: (any() -> boolean())
  def to_predicate(target, eq \\ Eq) do
    fn elem ->
      case eq do
        module when is_atom(module) -> module.eq?(elem, target)
        %{} = custom_map -> custom_map[:eq?].(elem, target)
      end
    end
  end
end
