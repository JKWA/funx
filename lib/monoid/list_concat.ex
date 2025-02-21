defmodule Monex.Monoid.ListConcat do
  @moduledoc """
  A Monoid implementation for concatenating lists.

  This monoid uses list concatenation as its associative operation
  and `[]` as the identity element.
  """

  @type t :: %__MODULE__{value: list()}

  defstruct value: []
end

defimpl Monex.Monoid, for: Monex.Monoid.ListConcat do
  alias Monex.Monoid.ListConcat

  @spec empty(ListConcat.t()) :: ListConcat.t()
  def empty(_), do: %ListConcat{}

  @spec append(ListConcat.t(), ListConcat.t()) :: ListConcat.t()
  def append(%ListConcat{value: a}, %ListConcat{value: b}) do
    %ListConcat{value: a ++ b}
  end

  @spec wrap(ListConcat.t(), list()) :: ListConcat.t()
  def wrap(%ListConcat{}, value) when is_list(value), do: %ListConcat{value: value}

  @spec unwrap(ListConcat.t()) :: list()
  def unwrap(%ListConcat{value: value}), do: value
end
