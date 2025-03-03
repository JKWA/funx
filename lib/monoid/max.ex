defmodule Funx.Monoid.Max do
  @moduledoc """
  A Monoid implementation for maximum values.
  """

  defstruct value: nil, ord: Funx.Ord
end

defimpl Funx.Monoid, for: Funx.Monoid.Max do
  alias Funx.Monoid.Max
  alias Funx.Ord.Utils

  def empty(%Max{value: min_value, ord: ord}) do
    %Max{value: min_value, ord: ord}
  end

  def append(%Max{value: a, ord: ord}, %Max{value: b}) do
    %Max{value: Utils.max(a, b, ord), ord: ord}
  end

  def wrap(%Max{ord: ord}, value) do
    %Max{value: value, ord: Utils.to_ord_map(ord)}
  end

  def unwrap(%Max{value: value}), do: value
end
