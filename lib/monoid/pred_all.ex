# credo:disable-for-this-file

defmodule Funx.Monoid.Predicate.All do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonoid%2Fpred_all.livemd)

  A Monoid implementation for combining predicates using logical AND.
  """
  defstruct value: &Funx.Monoid.Predicate.All.default_pred?/1

  def default_pred?(_), do: true
end

defimpl Funx.Monoid, for: Funx.Monoid.Predicate.All do
  alias Funx.Monoid.Predicate.All

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
