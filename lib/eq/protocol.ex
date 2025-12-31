defprotocol Funx.Eq.Protocol do
  @moduledoc """
  The `Funx.Eq.Protocol` protocol defines an equality function, `eq?/2`, for comparing two values,
  and its complement, `not_eq?/2`, for checking inequality.

  Types that implement this protocol can define custom equality logic, allowing for
  domain-specific comparisons.

  ## Fallback
  The protocol uses `@fallback_to_any true`, meaning that if a specific type does not
  implement `Funx.Eq.Protocol`, it falls back to the default implementation for `Any`, which
  uses Elixir's built-in equality operator (`==`).

  ## Examples

  With a custom implementation for a `Funx.Monad.Maybe` type:

      iex> Funx.Eq.Protocol.eq?(Funx.Monad.Maybe.just(3), Funx.Monad.Maybe.just(3))
      true

      iex> Funx.Eq.Protocol.eq?(Funx.Monad.Maybe.just(3), Funx.Monad.Maybe.just(5))
      false

      iex> Funx.Eq.Protocol.eq?(Funx.Monad.Maybe.nothing(), Funx.Monad.Maybe.nothing())
      true

      iex> Funx.Eq.Protocol.eq?(Funx.Monad.Maybe.nothing(), Funx.Monad.Maybe.just(5))
      false

  Checking inequality with `not_eq?/2`:

      iex> Funx.Eq.Protocol.not_eq?(Funx.Monad.Maybe.just(3), Funx.Monad.Maybe.just(3))
      false

      iex> Funx.Eq.Protocol.not_eq?(Funx.Monad.Maybe.just(3), Funx.Monad.Maybe.just(5))
      true

      iex> Funx.Eq.Protocol.not_eq?(Funx.Monad.Maybe.nothing(), Funx.Monad.Maybe.nothing())
      false

      iex> Funx.Eq.Protocol.not_eq?(Funx.Monad.Maybe.nothing(), Funx.Monad.Maybe.just(5))
      true
  """

  @fallback_to_any true

  @doc """
  Returns `true` if `a` is equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Funx.Eq.Protocol.eq?(1, 1)
      true

      iex> Funx.Eq.Protocol.eq?(1, 2)
      false
  """
  def eq?(a, b)

  @doc """
  Returns `true` if `a` is not equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Funx.Eq.Protocol.not_eq?(1, 1)
      false

      iex> Funx.Eq.Protocol.not_eq?(1, 2)
      true
  """
  def not_eq?(a, b)
end

defimpl Funx.Eq.Protocol, for: Any do
  @spec eq?(any(), any()) :: boolean()
  def eq?(a, b), do: a == b

  @spec not_eq?(any(), any()) :: boolean()
  def not_eq?(a, b), do: a != b
end

defimpl Funx.Eq.Protocol, for: DateTime do
  @spec eq?(DateTime.t(), DateTime.t()) :: boolean()
  def eq?(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) == :eq

  @spec not_eq?(DateTime.t(), DateTime.t()) :: boolean()
  def not_eq?(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) != :eq
end

defimpl Funx.Eq.Protocol, for: Date do
  @spec eq?(Date.t(), Date.t()) :: boolean()
  def eq?(%Date{} = a, %Date{} = b), do: Date.compare(a, b) == :eq

  @spec not_eq?(Date.t(), Date.t()) :: boolean()
  def not_eq?(%Date{} = a, %Date{} = b), do: Date.compare(a, b) != :eq
end

defimpl Funx.Eq.Protocol, for: Time do
  @spec eq?(Time.t(), Time.t()) :: boolean()
  def eq?(%Time{} = a, %Time{} = b), do: Time.compare(a, b) == :eq

  @spec not_eq?(Time.t(), Time.t()) :: boolean()
  def not_eq?(%Time{} = a, %Time{} = b), do: Time.compare(a, b) != :eq
end

defimpl Funx.Eq.Protocol, for: NaiveDateTime do
  @spec eq?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean()
  def eq?(%NaiveDateTime{} = a, %NaiveDateTime{} = b), do: NaiveDateTime.compare(a, b) == :eq

  @spec not_eq?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean()
  def not_eq?(%NaiveDateTime{} = a, %NaiveDateTime{} = b), do: NaiveDateTime.compare(a, b) != :eq
end
