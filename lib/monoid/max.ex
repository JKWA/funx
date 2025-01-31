defmodule Monex.Monoid.Max do
  @moduledoc """
  A Monoid implementation for maximum values.
  """

  defstruct value: nil, ord: Monex.Ord
end

defimpl Monex.Monoid, for: Monex.Monoid.Max do
  alias Monex.Monoid.Max

  def empty(%Max{value: min_value, ord: ord}) do
    %Max{value: min_value, ord: ord}
  end

  def append(%Max{value: a, ord: ord}, %Max{value: b}) do
    %Max{value: Monex.Ord.Utils.max(a, b, ord), ord: ord}
  end

  def wrap(%Max{ord: ord}, value) do
    %Max{value: value, ord: to_map(ord)}
  end

  def unwrap(%Max{value: value}), do: value

  defp to_map(ord) when is_map(ord), do: ord

  defp to_map(ord) when is_atom(ord) do
    %{
      lt?: &ord.lt?/2,
      le?: &ord.le?/2,
      gt?: &ord.gt?/2,
      ge?: &ord.ge?/2
    }
  end
end
