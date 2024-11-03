defmodule Monex.Operators do
  @moduledoc """
  Provides custom operators for monadic operations in the Monex library.

  This module defines the following operators for convenient chaining of monadic functions:
    - `<<~`: Applicative apply, used to apply a function wrapped in a monad to a value in another monad.
    - `~>>`: Monadic bind, used to chain monadic operations.
    - `~>`: Functor map, used to apply a function to the value inside a monad.
  """

  @doc """
  Applies a function wrapped in a monad (`left`) to a value in another monad (`right`).

  This is an applicative apply operation that uses `Monex.Monad.ap/2`.

  ## Examples

      iex> Monex.Just(fn x -> x * 2) <<~ Monex.Just(3)
      %Monex.Just{value: 6}
  """
  @spec Monex.Monad.t() <<~ Monex.Monad.t() :: Monex.Monad.t()
  defmacro left <<~ right do
    quote do
      Monex.Monad.ap(unquote(left), unquote(right))
    end
  end

  @doc """
  Chains two monadic operations, passing the result of `left` to `right`.

  This is a monadic bind operation that uses `Monex.Monad.bind/2`.

  ## Examples

      iex> Monex.Just(3) ~>> fn x -> Monex.Just(x + 1) end
      %Monex.Just{value: 4}
  """
  @spec Monex.Monad.t() ~>> (term() -> Monex.Monad.t()) :: Monex.Monad.t()
  defmacro left ~>> right do
    quote do
      Monex.Monad.bind(unquote(left), unquote(right))
    end
  end

  @doc """
  Applies a function (`right`) to the value inside a monad (`left`).

  This is a functor map operation that uses `Monex.Monad.map/2`.

  ## Examples

      iex> Monex.Just(3) ~> fn x -> x + 1 end
      %Monex.Just{value: 4}
  """
  @spec Monex.Monad.t() ~> (term() -> term()) :: Monex.Monad.t()
  defmacro left ~> right do
    quote do
      Monex.Monad.map(unquote(left), unquote(right))
    end
  end
end
