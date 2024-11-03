defprotocol Monex.Eq do
  @moduledoc """
  The `Monex.Eq` protocol defines an equality function, `eq?/2`, for comparing two values.

  Types that implement this protocol can define custom equality logic for comparing instances of their type.

  ## Fallback
  The protocol uses `@fallback_to_any true`, meaning that if a specific type does not implement `Monex.Eq`,
  it falls back to the default implementation for `Any`, which uses Elixir's built-in equality operator (`==`).
  """

  @fallback_to_any true

  @doc """
  Returns `true` if `a` is equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Monex.Eq.eq?(Monex.Maybe.just(3), Monex.Maybe.just(3))
      true

      iex> Monex.Eq.eq?(Monex.Maybe.just(3), Monex.Maybe.just(5))
      false

      iex> Monex.Eq.eq?(Monex.Maybe.nothing(), Monex.Maybe.nothing())
      true

      iex> Monex.Eq.eq?(Monex.Maybe.nothing(), Monex.Maybe.just(5))
      false
  """
  def eq?(a, b)

  @doc """
  Creates an `Eq` instance for Monads given an `Eq` for the inner value.
  """
  def get_eq(eq_for_value)
end

defimpl Monex.Eq, for: Any do
  @moduledoc """
  Provides a default implementation of the `Monex.Eq` protocol for all types that fall back to the `Any` type.

  This implementation uses Elixir's built-in equality operator (`==`) to compare values.
  """

  @doc """
  Returns `true` if `a` is equal to `b`, otherwise returns `false`.

  Uses Elixir's `==` operator for comparison.

  ## Examples

      iex> Monex.Eq.eq?(3, 3)
      true

      iex> Monex.Eq.eq?(3, 5)
      false
  """
  def eq?(a, b), do: a == b

  @doc """
  Returns a generic `Eq` instance based on the default equality behavior for any type.

  If the `Eq` instance provided for the inner type can’t be matched specifically,
  it falls back to using `==` for any values.

  ## Examples

      iex> default_eq = Monex.Eq.get_eq(Monex.Eq)
      iex> default_eq[:eq?].(3, 3)
      true

      iex> default_eq[:eq?].(3, 5)
      false
  """
  def get_eq(_inner_eq) do
    %{
      eq?: fn a, b -> a == b end
    }
  end
end
