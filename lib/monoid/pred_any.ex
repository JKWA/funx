# credo:disable-for-this-file

defmodule Funx.Monoid.Predicate.Any do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fpred_any.livemd)

  A Monoid implementation for combining predicates using logical OR.
  """
  defstruct value: &Funx.Monoid.Predicate.Any.default_pred?/1

  def default_pred?(_), do: false
end

defimpl Funx.Monoid, for: Funx.Monoid.Predicate.Any do
  alias Funx.Monoid.Predicate.Any

  def empty(_), do: %Any{}

  def append(%Any{} = p1, %Any{} = p2) do
    %Any{
      value: fn value -> p1.value.(value) or p2.value.(value) end
    }
  end

  def wrap(%Any{}, value) when is_function(value, 1) do
    %Any{value: value}
  end

  def unwrap(%Any{value: value}), do: value
end
