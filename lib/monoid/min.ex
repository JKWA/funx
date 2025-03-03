defmodule Funx.Monoid.Min do
  @moduledoc """
  A Monoid implementation for minimum values.
  """

  defstruct value: nil, ord: Funx.Ord
end

defimpl Funx.Monoid, for: Funx.Monoid.Min do
  alias Funx.Monoid.Min
  alias Funx.Ord.Utils

  def empty(%Min{value: max_value, ord: ord}) do
    %Min{value: max_value, ord: ord}
  end

  def append(%Min{value: a, ord: ord}, %Min{value: b}) do
    %Min{value: Utils.min(a, b, ord), ord: ord}
  end

  def wrap(%Min{ord: ord}, value) do
    %Min{value: value, ord: Utils.to_ord_map(ord)}
  end

  def unwrap(%Min{value: value}), do: value
end
