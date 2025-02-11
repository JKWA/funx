defmodule Monex.Utils do
  @moduledoc """
  A collection of higher-order functions for functional programming in Elixir.

  This module provides utilities for working with functions in a functional
  programming style. It includes:

  - `curry/1`: Transforms a multi-argument function into a curried version.
  - `flip/1`: Reverses the argument order of a two-argument function.
  """

  @doc """
  Transforms a function of arity `n` into a curried version,
  allowing it to be applied one argument at a time.

  ## Example

      iex> add = fn a, b -> a + b end
      iex> curried_add = FunPark.Utils.curry(add)
      iex> add_three = curried_add.(3)
      iex> add_three.(2)
      5
  """
  @spec curry((... -> any())) :: any()
  def curry(fun) when is_function(fun) do
    arity = :erlang.fun_info(fun, :arity) |> elem(1)
    curry(fun, arity, [])
  end

  defp curry(fun, 1, args),
    do: fn last_arg -> apply(fun, args ++ [last_arg]) end

  defp curry(fun, arity, args) when arity > 1 do
    fn next_arg -> curry(fun, arity - 1, args ++ [next_arg]) end
  end

  @doc """
  Reverses the argument order of a two-argument function.

  The `flip/1` function takes a function of arity 2 and returns a new function
  where the first and second arguments are swapped.

  ## Examples

      iex> divide = fn a, b -> a / b end
      iex> flipped_divide = Utils.flip(divide)
      iex> flipped_divide.(2, 10)
      5.0

  """
  @spec flip((a, b -> c)) :: (b, a -> c) when a: any(), b: any(), c: any()
  def flip(fun) when is_function(fun, 2) do
    fn a, b -> fun.(b, a) end
  end
end
