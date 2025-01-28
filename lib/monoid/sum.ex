defmodule Monex.Monoid.Sum do
  @moduledoc """
  A Monoid implementation for sums.

  This monoid uses addition as its associative operation
  and `0` as the identity element.
  """

  @type t :: %__MODULE__{value: number()}

  defstruct value: 0
end

defimpl Monex.Monoid, for: Monex.Monoid.Sum do
  alias Monex.Monoid.Sum

  @spec empty(Sum.t()) :: Sum.t()
  def empty(_), do: %Sum{}

  @spec append(Sum.t(), Sum.t()) :: Sum.t()
  def append(%Sum{value: a}, %Sum{value: b}) do
    %Sum{value: a + b}
  end

  @spec wrap(Sum.t(), number()) :: Sum.t()
  def wrap(%Sum{}, value), do: %Sum{value: value}

  @spec unwrap(Sum.t()) :: number()
  def unwrap(%Sum{value: value}), do: value
end
