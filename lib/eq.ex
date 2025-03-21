defprotocol Funx.Eq do
  @moduledoc """
  The `Funx.Eq` protocol defines an equality function, `eq?/2`, for comparing two values,
  and its complement, `not_eq?/2`, for checking inequality.

  Types that implement this protocol can define custom equality logic, allowing for
  domain-specific comparisons.

  ## Fallback
  The protocol uses `@fallback_to_any true`, meaning that if a specific type does not
  implement `Funx.Eq`, it falls back to the default implementation for `Any`, which
  uses Elixir's built-in equality operator (`==`).

  ## Examples

  With a custom implementation for a `Funx.Maybe` type:

      iex> Funx.Eq.eq?(Funx.Maybe.just(3), Funx.Maybe.just(3))
      true

      iex> Funx.Eq.eq?(Funx.Maybe.just(3), Funx.Maybe.just(5))
      false

      iex> Funx.Eq.eq?(Funx.Maybe.nothing(), Funx.Maybe.nothing())
      true

      iex> Funx.Eq.eq?(Funx.Maybe.nothing(), Funx.Maybe.just(5))
      false

  Checking inequality with `not_eq?/2`:

      iex> Funx.Eq.not_eq?(Funx.Maybe.just(3), Funx.Maybe.just(3))
      false

      iex> Funx.Eq.not_eq?(Funx.Maybe.just(3), Funx.Maybe.just(5))
      true

      iex> Funx.Eq.not_eq?(Funx.Maybe.nothing(), Funx.Maybe.nothing())
      false

      iex> Funx.Eq.not_eq?(Funx.Maybe.nothing(), Funx.Maybe.just(5))
      true
  """

  @fallback_to_any true

  @doc """
  Returns `true` if `a` is equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Funx.Eq.eq?(1, 1)
      true

      iex> Funx.Eq.eq?(1, 2)
      false
  """
  def eq?(a, b)

  @doc """
  Returns `true` if `a` is not equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Funx.Eq.not_eq?(1, 1)
      false

      iex> Funx.Eq.not_eq?(1, 2)
      true
  """
  def not_eq?(a, b)
end

defimpl Funx.Eq, for: Any do
  @spec eq?(any(), any()) :: boolean()
  def eq?(a, b), do: a == b

  @spec not_eq?(any(), any()) :: boolean()
  def not_eq?(a, b), do: a != b
end

defimpl Funx.Eq, for: DateTime do
  @spec eq?(DateTime.t(), DateTime.t()) :: boolean()
  def eq?(a, b), do: DateTime.compare(a, b) == :eq

  @spec not_eq?(DateTime.t(), DateTime.t()) :: boolean()
  def not_eq?(a, b), do: DateTime.compare(a, b) != :eq
end

defimpl Funx.Eq, for: Date do
  @spec eq?(Date.t(), Date.t()) :: boolean()
  def eq?(a, b), do: Date.compare(a, b) == :eq

  @spec not_eq?(Date.t(), Date.t()) :: boolean()
  def not_eq?(a, b), do: Date.compare(a, b) != :eq
end

defimpl Funx.Eq, for: Time do
  @spec eq?(Time.t(), Time.t()) :: boolean()
  def eq?(a, b), do: Time.compare(a, b) == :eq

  @spec not_eq?(Time.t(), Time.t()) :: boolean()
  def not_eq?(a, b), do: Time.compare(a, b) != :eq
end

defimpl Funx.Eq, for: NaiveDateTime do
  @spec eq?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean()
  def eq?(a, b), do: NaiveDateTime.compare(a, b) == :eq

  @spec not_eq?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean()
  def not_eq?(a, b), do: NaiveDateTime.compare(a, b) != :eq
end
