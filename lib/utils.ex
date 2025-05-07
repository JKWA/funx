defmodule Funx.Utils do
  @moduledoc """
  A collection of higher-order functions for functional programming in Elixir.

  This module provides utilities for working with functions in a functional
  programming style. It includes:

  - `curry/1`: Transforms a multi-argument function into a curried version.
  - `curry_r/1`: Transforms a multi-argument function into a curried version, but from right to left.
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
  Alias for `curry/1`, explicitly denoting left-to-right argument application.

  ## Example

      iex> subtract = fn a, b -> a - b end
      iex> curried_subtract = FunPark.Utils.curry_l(subtract)
      iex> subtract_five = curried_subtract.(5)
      iex> subtract_five.(3)
      2
  """
  @spec curry_l((... -> any())) :: any()

  def curry_l(fun) when is_function(fun), do: curry(fun)

  @doc """
  Transforms a function of arity `n` into a right-curried version,
  applying arguments from right to left.

  ## Example

      iex> divide = fn a, b -> a / b end
      iex> curried_divide = FunPark.Utils.curry_r(divide)
      iex> divide_by_two = curried_divide.(2)
      iex> divide_by_two.(10)
      5.0
  """
  @spec curry_r((... -> any())) :: any()
  def curry_r(fun) when is_function(fun) do
    arity = :erlang.fun_info(fun, :arity) |> elem(1)
    curry_r(fun, arity, [])
  end

  defp curry_r(fun, 1, args),
    do: fn last_arg -> apply(fun, [last_arg | args]) end

  defp curry_r(fun, arity, args) when arity > 1 do
    fn next_arg -> curry_r(fun, arity - 1, [next_arg | args]) end
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

  def summarize_string(value, max_len \\ 50) when is_binary(value) do
    if String.length(value) > max_len do
      String.slice(value, 0, max_len) <> "..."
    else
      value
    end
  end
end
