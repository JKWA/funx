defprotocol Monex.Eq do
  @moduledoc """
  The `Monex.Eq` protocol defines an equality function, `eq?/2`, for comparing two values,
  and its complement, `not_eq?/2`, for checking inequality.

  Types that implement this protocol can define custom equality logic, allowing for
  domain-specific comparisons.

  ## Fallback
  The protocol uses `@fallback_to_any true`, meaning that if a specific type does not
  implement `Monex.Eq`, it falls back to the default implementation for `Any`, which
  uses Elixir's built-in equality operator (`==`).

  ## Examples

  With a custom implementation for a `Monex.Maybe` type:

      iex> Monex.Eq.eq?(Monex.Maybe.just(3), Monex.Maybe.just(3))
      true

      iex> Monex.Eq.eq?(Monex.Maybe.just(3), Monex.Maybe.just(5))
      false

      iex> Monex.Eq.eq?(Monex.Maybe.nothing(), Monex.Maybe.nothing())
      true

      iex> Monex.Eq.eq?(Monex.Maybe.nothing(), Monex.Maybe.just(5))
      false

  Checking inequality with `not_eq?/2`:

      iex> Monex.Eq.not_eq?(Monex.Maybe.just(3), Monex.Maybe.just(3))
      false

      iex> Monex.Eq.not_eq?(Monex.Maybe.just(3), Monex.Maybe.just(5))
      true

      iex> Monex.Eq.not_eq?(Monex.Maybe.nothing(), Monex.Maybe.nothing())
      false

      iex> Monex.Eq.not_eq?(Monex.Maybe.nothing(), Monex.Maybe.just(5))
      true
  """

  @fallback_to_any true

  @doc """
  Returns `true` if `a` is equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Monex.Eq.eq?(1, 1)
      true

      iex> Monex.Eq.eq?(1, 2)
      false
  """
  def eq?(a, b)

  @doc """
  Returns `true` if `a` is not equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Monex.Eq.not_eq?(1, 1)
      false

      iex> Monex.Eq.not_eq?(1, 2)
      true
  """
  def not_eq?(a, b)
end

defimpl Monex.Eq, for: Any do
  @moduledoc """
  Provides a default implementation of the `Monex.Eq` protocol for all types that fall back to the `Any` type.

  This implementation uses Elixir's built-in equality operator (`==`) to compare values.
  """

  def eq?(a, b), do: a == b
  def not_eq?(a, b), do: a != b
end
