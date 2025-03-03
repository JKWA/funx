defmodule Funx.Operators do
  @moduledoc """
  Provides custom operators for monadic operations in the Funx library.

  This module defines the following operators for convenient chaining of monadic functions:
    - `<<~`: Applicative apply, used to apply a function wrapped in a monad to a value in another monad.
    - `~>>`: Monadic bind, used to chain monadic operations.
    - `~>`: Functor map, used to apply a function to the value inside a monad.
  """

  @doc """
  Applies a function wrapped in a monad (`left`) to a value in another monad (`right`).

  This is an applicative apply operation that uses `Funx.Monad.ap/2`.

  ## Examples

      iex> Funx.Just(fn x -> x * 2) <<~ Funx.Just(3)
      %Funx.Just{value: 6}
  """
  @spec Funx.Monad.t() <<~ Funx.Monad.t() :: Funx.Monad.t()
  defmacro left <<~ right do
    quote do
      Funx.Monad.ap(unquote(left), unquote(right))
    end
  end

  @doc """
  Chains two monadic operations, passing the result of `left` to `right`.

  This is a monadic bind operation that uses `Funx.Monad.bind/2`.

  ## Examples

      iex> Funx.Just(3) ~>> fn x -> Funx.Just(x + 1) end
      %Funx.Just{value: 4}
  """
  @spec Funx.Monad.t() ~>> (term() -> Funx.Monad.t()) :: Funx.Monad.t()
  defmacro left ~>> right do
    quote do
      Funx.Monad.bind(unquote(left), unquote(right))
    end
  end

  @doc """
  Applies a function (`right`) to the value inside a monad (`left`).

  This is a functor map operation that uses `Funx.Monad.map/2`.

  ## Examples

      iex> Funx.Just(3) ~> fn x -> x + 1 end
      %Funx.Just{value: 4}
  """
  @spec Funx.Monad.t() ~> (term() -> term()) :: Funx.Monad.t()
  defmacro left ~> right do
    quote do
      Funx.Monad.map(unquote(left), unquote(right))
    end
  end
end
