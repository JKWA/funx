defmodule Funx.Monoid.ListConcat do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Flist_concat.livemd)

  A Monoid implementation for concatenating lists.

  This monoid uses list concatenation as its associative operation
  and `[]` as the identity element.
  """

  @type t :: %__MODULE__{value: list()}

  defstruct value: []
end

defimpl Funx.Monoid, for: Funx.Monoid.ListConcat do
  alias Funx.Monoid.ListConcat

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
