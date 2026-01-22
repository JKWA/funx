defmodule Funx.Monoid.Min do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fmin.livemd)

  A Monoid implementation for minimum values.
  """

  defstruct value: nil, ord: Funx.Ord.Protocol
end

defimpl Funx.Monoid, for: Funx.Monoid.Min do
  alias Funx.Monoid.Min

  def empty(%Min{value: max_value, ord: ord}) do
    %Min{value: max_value, ord: ord}
  end

  def append(%Min{value: a, ord: ord}, %Min{value: b}) do
    %Min{value: Funx.Ord.min(a, b, ord), ord: ord}
  end

  def wrap(%Min{ord: ord}, value) do
    %Min{value: value, ord: Funx.Ord.to_ord_map(ord)}
  end

  def unwrap(%Min{value: value}), do: value
end
