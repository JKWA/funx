defprotocol Monex.Ord do
  @moduledoc """
  The `Monex.Ord` protocol defines a set of comparison functions: `lt?/2`, `le?/2`, `gt?/2`, and `ge?/2`.

  This protocol is intended for types that can be ordered, allowing values to be compared for their relative positions in a total order.

  By implementing this protocol, you can provide custom logic for how values of a certain type are compared.

  ## Fallback
  The protocol uses `@fallback_to_any true`, which means if a specific type does not implement `Monex.Ord`,
  the default implementation for `Any` will be used, which relies on Elixir's built-in comparison operators.
  """

  @fallback_to_any true

  @doc """
  Returns `true` if `a` is less than `b`, otherwise returns `false`.

  ## Examples

      iex> Monex.Ord.lt?(Monex.Maybe.just(3), Monex.Maybe.just(5))
      true

      iex> Monex.Ord.lt?(Monex.Maybe.just(5), Monex.Maybe.just(3))
      false

      iex> Monex.Ord.lt?(Monex.Maybe.nothing(), Monex.Maybe.just(3))
      true
  """
  def lt?(a, b)

  @doc """
  Returns `true` if `a` is less than or equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Monex.Ord.le?(Monex.Maybe.just(3), Monex.Maybe.just(5))
      true

      iex> Monex.Ord.le?(Monex.Maybe.just(5), Monex.Maybe.just(5))
      true

      iex> Monex.Ord.le?(Monex.Maybe.just(5), Monex.Maybe.just(3))
      false
  """
  def le?(a, b)

  @doc """
  Returns `true` if `a` is greater than `b`, otherwise returns `false`.

  ## Examples

      iex> Monex.Ord.gt?(Monex.Maybe.just(5), Monex.Maybe.just(3))
      true

      iex> Monex.Ord.gt?(Monex.Maybe.just(3), Monex.Maybe.just(5))
      false

      iex> Monex.Ord.gt?(Monex.Maybe.just(3), Monex.Maybe.nothing())
      true
  """
  def gt?(a, b)

  @doc """
  Returns `true` if `a` is greater than or equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Monex.Ord.ge?(Monex.Maybe.just(5), Monex.Maybe.just(3))
      true

      iex> Monex.Ord.ge?(Monex.Maybe.just(5), Monex.Maybe.just(5))
      true

      iex> Monex.Ord.ge?(Monex.Maybe.just(3), Monex.Maybe.just(5))
      false
  """
  def ge?(a, b)
end

defimpl Monex.Ord, for: Any do
  @moduledoc """
  Provides a default implementation of the `Monex.Ord` protocol for all types that fall back to the `Any` type.

  This implementation uses Elixir's built-in comparison operators to compare values.
  """

  @doc """
  Returns `true` if `a` is less than `b`, otherwise returns `false`.

  Uses Elixir's `<` operator for comparison.

  ## Examples

      iex> Monex.Ord.lt?(Monex.Maybe.just(3), Monex.Maybe.just(5))
      true

      iex> Monex.Ord.lt?(Monex.Maybe.nothing(), Monex.Maybe.just(5))
      true
  """
  @spec lt?(any(), any()) :: boolean()
  def lt?(a, b), do: a < b

  @doc """
  Returns `true` if `a` is less than or equal to `b`, otherwise returns `false`.

  Uses Elixir's `<=` operator for comparison.

  ## Examples

      iex> Monex.Ord.le?(Monex.Maybe.just(3), Monex.Maybe.just(5))
      true

      iex> Monex.Ord.le?(Monex.Maybe.just(5), Monex.Maybe.just(5))
      true
  """
  @spec le?(any(), any()) :: boolean()
  def le?(a, b), do: a <= b

  @doc """
  Returns `true` if `a` is greater than `b`, otherwise returns `false`.

  Uses Elixir's `>` operator for comparison.

  ## Examples

      iex> Monex.Ord.gt?(Monex.Maybe.just(5), Monex.Maybe.just(3))
      true

      iex> Monex.Ord.gt?(Monex.Maybe.just(3), Monex.Maybe.nothing())
      true
  """
  @spec gt?(any(), any()) :: boolean()
  def gt?(a, b), do: a > b

  @doc """
  Returns `true` if `a` is greater than or equal to `b`, otherwise returns `false`.

  Uses Elixir's `>=` operator for comparison.

  ## Examples

      iex> Monex.Ord.ge?(Monex.Maybe.just(5), Monex.Maybe.just(5))
      true

      iex> Monex.Ord.ge?(Monex.Maybe.just(3), Monex.Maybe.just(5))
      false
  """
  @spec ge?(any(), any()) :: boolean()
  def ge?(a, b), do: a >= b
end
