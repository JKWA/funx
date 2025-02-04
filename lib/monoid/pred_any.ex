# credo:disable-for-this-file

defmodule Monex.Monoid.Predicate.Any do
  @moduledoc """
  A Monoid implementation for combining predicates using logical OR.
  """
  defstruct value: &Monex.Monoid.Predicate.Any.default_pred?/1

  def default_pred?(_), do: false
end

defimpl Monex.Monoid, for: Monex.Monoid.Predicate.Any do
  alias Monex.Monoid.Predicate.Any
  alias Monex.Predicate

  def empty(_), do: %Any{}

  def append(%Any{} = p1, %Any{} = p2) do
    %Any{
      value: Predicate.p_or(p1.value, p2.value)
    }
  end

  def wrap(%Any{}, value) when is_function(value, 1) do
    %Any{value: value}
  end

  def unwrap(%Any{value: value}), do: value
end
