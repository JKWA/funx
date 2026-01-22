defmodule Funx.Monoid.Sum do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fsum.livemd)

  A Monoid implementation for sums.

  This monoid uses addition as its associative operation
  and `0` as the identity element.
  """

  @type t :: %__MODULE__{value: number()}

  defstruct value: 0
end

defimpl Funx.Monoid, for: Funx.Monoid.Sum do
  alias Funx.Monoid.Sum

  @spec empty(Sum.t()) :: Sum.t()
  def empty(_), do: %Sum{}

  @spec append(Sum.t(), Sum.t()) :: Sum.t()
  def append(%Sum{value: a}, %Sum{value: b}) do
    %Sum{value: a + b}
  end

  @spec wrap(Sum.t(), number()) :: Sum.t()
  def wrap(%Sum{}, value) when is_number(value), do: %Sum{value: value}

  @spec unwrap(Sum.t()) :: number()
  def unwrap(%Sum{value: value}) when is_number(value), do: value
end
