defmodule Monex.Effect.Left do
  @moduledoc """
  Represents the `Left` variant of the `Effect` monad, used to model an error or failure in an asynchronous context.

  This module implements the following protocols:
    - `Monex.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations within an effectful, lazy execution.
    - `String.Chars`: Provides a `to_string/1` function to represent `Left` values as strings.

  The `Left` effect propagates the wrapped error or failure without executing further success logic, supporting lazy, asynchronous tasks.
  """
  @enforce_keys [:effect]
  defstruct [:effect]

  @type t(left) :: %__MODULE__{effect: (-> Task.t(%Monex.Either.Left{value: left}))}

  @doc """
  Creates a new `Left` effect.

  The `pure/1` function wraps a value in the `Left` effect monad, representing an asynchronous error or failure.

  ## Examples

      iex> Monex.Effect.Left.pure("error")
      %Monex.Effect.Left{
        effect: #Function<...>  # (an asynchronous task returning `Left`)
      }
  """
  @spec pure(left) :: t(left) when left: term()
  def pure(value) do
    %__MODULE__{
      effect: fn -> Task.async(fn -> %Monex.Either.Left{value: value} end) end
    }
  end

  defimpl Monex.Monad do
    alias Monex.Effect.Left

    @spec bind(Left.t(left), (any() -> Monex.Effect.t(left, result))) :: Left.t(left)
          when left: term(), result: term()
    def bind(%Left{effect: effect}, _binder) do
      %Left{
        effect: fn ->
          Task.async(fn ->
            Task.await(effect.())
          end)
        end
      }
    end

    @spec map(Left.t(left), (right -> result)) :: Left.t(left)
          when left: term(), right: term(), result: term()
    def map(%Left{effect: effect}, _mapper) do
      %Left{effect: effect}
    end

    @spec ap(Left.t(left), Monex.Effect.t(left, right)) :: Left.t(left)
          when left: term(), right: term()
    def ap(%Left{} = left, _), do: left
  end
end
