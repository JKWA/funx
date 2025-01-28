defmodule Monex.Monoid.Product do
  @moduledoc """
  A Monoid implementation for products.

  This monoid uses multiplication as its associative operation
  and `1` as the identity element.
  """

  @type t :: %__MODULE__{value: number()}

  defstruct value: 1
end

defimpl Monex.Monoid, for: Monex.Monoid.Product do
  alias Monex.Monoid.Product

  @spec empty(Product.t()) :: Product.t()
  def empty(_), do: %Product{}

  @spec append(Product.t(), Product.t()) :: Product.t()
  def append(%Product{value: a}, %Product{value: b}) do
    %Product{value: a * b}
  end

  @spec wrap(Product.t(), number()) :: Product.t()
  def wrap(%Product{}, value), do: %Product{value: value}

  @spec unwrap(Product.t()) :: number()
  def unwrap(%Product{value: value}), do: value
end
