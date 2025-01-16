defprotocol Monex.Monoid do
  @moduledoc """
  A protocol defining the Monoid algebraic structure, which consists of
  an identity element and an associative binary operation for combining values.

  This protocol provides four key functions:

  - `empty/1`: Returns the identity element for the given monoid.
  - `append/2`: Combines two values in the context of the monoid.
  - `wrap/2`: Wraps a value into the monoidal structure.
  - `unwrap/1`: Extracts the underlying value from the monoidal structure.
  """

  @doc """
  Returns the identity element for the given monoid.

  The identity element is a special value that satisfies the property:

      append(empty(monoid), x) == x
      append(x, empty(monoid)) == x

  ## Examples

      iex> Monex.Monoid.empty(%Monex.Monoid.Sum{})
      %Monex.Monoid.Sum{value: 0}
  """
  @spec empty(t()) :: t()
  def empty(monoid)

  @doc """
  Combines two values in the context of the monoid.

  The operation must satisfy associativity:

      append(append(a, b), c) == append(a, append(b, c))

  ## Examples

      iex> Monex.Monoid.append(%Monex.Monoid.Sum{value: 1}, %Monex.Monoid.Sum{value: 2})
      %Monex.Monoid.Sum{value: 3}
  """
  @spec append(t(), t()) :: t()
  def append(a, b)

  @doc """
  Wraps a value into the monoidal structure.

  ## Examples

      iex> Monex.Monoid.wrap(10, %Monex.Monoid.Sum{})
      %Monex.Monoid.Sum{value: 10}
  """
  @spec wrap(any(), t()) :: t()
  def wrap(value, monoid)

  @doc """
  Extracts the underlying value from the monoidal structure.

  ## Examples

      iex> Monex.Monoid.unwrap(%Monex.Monoid.Sum{value: 10})
      10
  """
  @spec unwrap(t()) :: any()
  def unwrap(monoid)
end
