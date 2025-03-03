defprotocol Monex.Monoid do
  @moduledoc """
  A protocol defining the Monoid algebraic structure, which consists of
  an identity element and an associative binary operation for combining values.

  This protocol provides four key functions:

  - `empty/1`: Returns the identity element for the given monoid.
  - `append/2`: Combines two monoid structs.
  - `wrap/2`: Wraps a value into the monoid struct.
  - `unwrap/1`: Extracts the underlying value from the monoid struct.
  """

  @doc """
  Returns the identity element for the given monoid struct.

  The identity element is a special value that satisfies the property:

      append(empty(monoid_struct), x) == x
      append(x, empty(monoid_struct)) == x

  ## Examples

      iex> Monex.Monoid.empty(%Monex.Monoid.Sum{})
      %Monex.Monoid.Sum{value: 0}
  """
  @spec empty(t()) :: t()
  def empty(monoid_struct)

  @doc """
  Combines two monoid structs.

  The operation must satisfy associativity:

      append(append(a, b), c) == append(a, append(b, c))

  ## Examples

      iex> Monex.Monoid.append(%Monex.Monoid.Sum{value: 1}, %Monex.Monoid.Sum{value: 2})
      %Monex.Monoid.Sum{value: 3}
  """
  @spec append(t(), t()) :: t()
  def append(monoid_struct_a, monoid_struct_b)

  @doc """
  Wraps a value into the given monoid struct.

  ## Examples

      iex> Monex.Monoid.wrap(%Monex.Monoid.Sum{}, 10)
      %Monex.Monoid.Sum{value: 10}
  """
  @spec wrap(t(), any()) :: t()
  def wrap(monoid_struct, value)

  @doc """
  Extracts the underlying value from the monoid struct.

  ## Examples

      iex> Monex.Monoid.unwrap(%Monex.Monoid.Sum{value: 10})
      10
  """
  @spec unwrap(t()) :: any()
  def unwrap(monoid_struct)
end
