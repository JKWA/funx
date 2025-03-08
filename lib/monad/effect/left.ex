defmodule Funx.Effect.Left do
  @moduledoc """
  Represents the `Left` variant of the `Effect` monad, used to model an error or failure in an asynchronous context.

  This module implements the following protocols:
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations within an effectful, lazy execution.
    - `String.Chars`: Provides a `to_string/1` function to represent `Left` values as strings.

  The `Left` effect propagates the wrapped error or failure without executing further success logic, supporting lazy, asynchronous tasks.
  """
  @enforce_keys [:effect]
  defstruct [:effect]

  @typedoc """
  Represents an asynchronous computation that produces a `Left` value.

  This type models an effectful computation that executes asynchronously, returning a `Task.t()`, which is expected to resolve to a `Left` value.

  Since Elixir does not allow parameterizing `Task.t()` with a return type, this type cannot enforce that `Task.t()` resolves to `Funx.Either.Left.t(left)`. However, all tasks within this structure are expected to eventually return a `Left` value.
  """
  @type t(left) :: %__MODULE__{
          effect: (-> Task.t()) | (-> Funx.Either.Left.t(left))
        }

  @doc """
  Creates a new `Left` effect.

  The `pure/1` function wraps a value in the `Left` effect monad, representing an asynchronous error or failure.

  ## Examples

      iex> Funx.Effect.Left.pure("error")
      %Funx.Effect.Left{
        effect: #Function<...>  # (an asynchronous task returning `Left`)
      }
  """
  @spec pure(left) :: t(left) when left: term()
  def pure(value) do
    %__MODULE__{
      effect: fn -> Task.async(fn -> %Funx.Either.Left{left: value} end) end
    }
  end
end

defimpl Funx.Monad, for: Funx.Effect.Left do
  alias Funx.Effect.Left

  @spec bind(Left.t(left), (any() -> Funx.Effect.t(left, result))) :: Left.t(left)
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

  @spec ap(Left.t(left), Funx.Effect.t(left, right)) :: Left.t(left)
        when left: term(), right: term()
  def ap(%Left{} = left, _), do: left
end
