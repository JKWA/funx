defprotocol Funx.Ord do
  @moduledoc """
  The `Funx.Ord` protocol defines a set of comparison functions: `lt?/2`, `le?/2`, `gt?/2`, and `ge?/2`.

  This protocol is intended for types that can be ordered, allowing values to be compared for their relative positions in a total order.

  By implementing this protocol, you can provide custom logic for how values of a certain type are compared.

  ## Fallback
  The protocol uses `@fallback_to_any true`, which means if a specific type does not implement `Funx.Ord`,
  the default implementation for `Any` will be used, which relies on Elixir's built-in comparison operators.
  """

  @fallback_to_any true

  @doc """
  Returns `true` if `a` is less than `b`, otherwise returns `false`.

  ## Examples

      iex> Funx.Ord.lt?(Funx.Monad.Maybe.just(3), Funx.Monad.Maybe.just(5))
      true

      iex> Funx.Ord.lt?(Funx.Monad.Maybe.just(5), Funx.Monad.Maybe.just(3))
      false

      iex> Funx.Ord.lt?(Funx.Monad.Maybe.nothing(), Funx.Monad.Maybe.just(3))
      true
  """
  def lt?(a, b)

  @doc """
  Returns `true` if `a` is less than or equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Funx.Ord.le?(Funx.Monad.Maybe.just(3), Funx.Monad.Maybe.just(5))
      true

      iex> Funx.Ord.le?(Funx.Monad.Maybe.just(5), Funx.Monad.Maybe.just(5))
      true

      iex> Funx.Ord.le?(Funx.Monad.Maybe.just(5), Funx.Monad.Maybe.just(3))
      false
  """
  def le?(a, b)

  @doc """
  Returns `true` if `a` is greater than `b`, otherwise returns `false`.

  ## Examples

      iex> Funx.Ord.gt?(Funx.Monad.Maybe.just(5), Funx.Monad.Maybe.just(3))
      true

      iex> Funx.Ord.gt?(Funx.Monad.Maybe.just(3), Funx.Monad.Maybe.just(5))
      false

      iex> Funx.Ord.gt?(Funx.Monad.Maybe.just(3), Funx.Monad.Maybe.nothing())
      true
  """
  def gt?(a, b)

  @doc """
  Returns `true` if `a` is greater than or equal to `b`, otherwise returns `false`.

  ## Examples

      iex> Funx.Ord.ge?(Funx.Monad.Maybe.just(5), Funx.Monad.Maybe.just(3))
      true

      iex> Funx.Ord.ge?(Funx.Monad.Maybe.just(5), Funx.Monad.Maybe.just(5))
      true

      iex> Funx.Ord.ge?(Funx.Monad.Maybe.just(3), Funx.Monad.Maybe.just(5))
      false
  """
  def ge?(a, b)
end

defimpl Funx.Ord, for: Any do
  @spec lt?(any(), any()) :: boolean()
  def lt?(a, b), do: a < b

  @spec le?(any(), any()) :: boolean()
  def le?(a, b), do: a <= b

  @spec gt?(any(), any()) :: boolean()
  def gt?(a, b), do: a > b

  @spec ge?(any(), any()) :: boolean()
  def ge?(a, b), do: a >= b
end

defimpl Funx.Ord, for: DateTime do
  @spec lt?(DateTime.t(), DateTime.t()) :: boolean()

  def lt?(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) == :lt

  @spec le?(DateTime.t(), DateTime.t()) :: boolean()
  def le?(%DateTime{} = a, %DateTime{} = b),
    do: match?(x when x in [:lt, :eq], DateTime.compare(a, b))

  @spec gt?(DateTime.t(), DateTime.t()) :: boolean()
  def gt?(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) == :gt

  @spec ge?(DateTime.t(), DateTime.t()) :: boolean()
  def ge?(%DateTime{} = a, %DateTime{} = b),
    do: match?(x when x in [:gt, :eq], DateTime.compare(a, b))
end

defimpl Funx.Ord, for: Date do
  @spec lt?(Date.t(), Date.t()) :: boolean()
  def lt?(a, b), do: Date.compare(a, b) == :lt

  @spec le?(Date.t(), Date.t()) :: boolean()
  def le?(a, b), do: match?(x when x in [:lt, :eq], Date.compare(a, b))

  @spec gt?(Date.t(), Date.t()) :: boolean()
  def gt?(a, b), do: Date.compare(a, b) == :gt

  @spec ge?(Date.t(), Date.t()) :: boolean()
  def ge?(a, b), do: match?(x when x in [:gt, :eq], Date.compare(a, b))
end

defimpl Funx.Ord, for: Time do
  @spec lt?(Time.t(), Time.t()) :: boolean()
  def lt?(%Time{} = a, %Time{} = b), do: Time.compare(a, b) == :lt

  @spec le?(Time.t(), Time.t()) :: boolean()
  def le?(%Time{} = a, %Time{} = b),
    do: match?(x when x in [:lt, :eq], Time.compare(a, b))

  @spec gt?(Time.t(), Time.t()) :: boolean()
  def gt?(%Time{} = a, %Time{} = b), do: Time.compare(a, b) == :gt

  @spec ge?(Time.t(), Time.t()) :: boolean()
  def ge?(%Time{} = a, %Time{} = b),
    do: match?(x when x in [:gt, :eq], Time.compare(a, b))
end

defimpl Funx.Ord, for: NaiveDateTime do
  @spec lt?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean()
  def lt?(%NaiveDateTime{} = a, %NaiveDateTime{} = b), do: NaiveDateTime.compare(a, b) == :lt

  @spec le?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean()
  def le?(%NaiveDateTime{} = a, %NaiveDateTime{} = b),
    do: match?(x when x in [:lt, :eq], NaiveDateTime.compare(a, b))

  @spec gt?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean()
  def gt?(%NaiveDateTime{} = a, %NaiveDateTime{} = b), do: NaiveDateTime.compare(a, b) == :gt

  @spec ge?(NaiveDateTime.t(), NaiveDateTime.t()) :: boolean()
  def ge?(%NaiveDateTime{} = a, %NaiveDateTime{} = b),
    do: match?(x when x in [:gt, :eq], NaiveDateTime.compare(a, b))
end
