defmodule Funx.Monoid.Product do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fproduct.livemd)

  A Monoid implementation for products.

  This monoid uses multiplication as its associative operation
  and `1` as the identity element.
  """

  @type t :: %__MODULE__{value: number()}

  defstruct value: 1
end

defimpl Funx.Monoid, for: Funx.Monoid.Product do
  alias Funx.Monoid.Product

  @spec empty(Product.t()) :: Product.t()
  def empty(_), do: %Product{}

  @spec append(Product.t(), Product.t()) :: Product.t()
  def append(%Product{value: a}, %Product{value: b}) do
    %Product{value: a * b}
  end

  @spec wrap(Product.t(), number()) :: Product.t()
  def wrap(%Product{}, value) when is_number(value), do: %Product{value: value}

  @spec unwrap(Product.t()) :: number()
  def unwrap(%Product{value: value}) when is_number(value), do: value
end
