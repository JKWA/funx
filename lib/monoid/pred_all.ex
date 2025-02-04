# credo:disable-for-this-file

defmodule Monex.Monoid.Predicate.All do
  @moduledoc """
  A Monoid implementation for combining predicates using logical AND.
  """
  defstruct value: &Monex.Monoid.Predicate.All.default_pred?/1

  def default_pred?(_), do: true
end

defimpl Monex.Monoid, for: Monex.Monoid.Predicate.All do
  alias Monex.Monoid.Predicate.All

  def empty(_), do: %All{}

  def append(%All{} = p1, %All{} = p2) do
    %All{
      value: fn value -> p1.value.(value) and p2.value.(value) end
    }
  end

  def wrap(%All{}, value) when is_function(value, 1) do
    %All{value: value}
  end

  def unwrap(%All{value: value}), do: value
end
