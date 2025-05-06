defmodule Funx.Effect.Right do
  @moduledoc """
  Represents the `Right` variant of the `Effect` monad, used to model a successful computation in an asynchronous context.

  This module implements the following protocols:
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions to handle monadic operations within an effectful, lazy execution context.
    - `String.Chars`: Provides a `to_string/1` function to represent `Right` values as strings.

  The `Right` effect allows the computation to proceed with successful values, supporting lazy, asynchronous tasks.
  """
  alias Funx.Either

  @enforce_keys [:effect]
  defstruct [:effect]

  @typedoc """
  Represents an asynchronous computation that produces a `Right` value.

  This type models an effectful computation that executes asynchronously, returning a `Task.t()`, which is expected to resolve to a `Right` value.

  Since Elixir does not allow parameterizing `Task.t()` with a return type, this type cannot enforce that `Task.t()` resolves to `Funx.Either.Right.t(right)`. However, all tasks within this structure are expected to eventually return a `Right` value.
  """

  @type t(right) :: %__MODULE__{
          effect: (-> Task.t()) | (-> Either.Right.t(right))
        }

  @doc """
  Creates a new `Right` effect.

  The `pure/1` function wraps a value in the `Right` effect monad, representing an asynchronous success.

  ## Examples

      iex> effect = Funx.Effect.Right.pure("success")
      iex> Funx.Effect.run(effect)
      %Funx.Either.Right{right: "success"}
  """
  @spec pure(right) :: t(right) when right: term()
  def pure(value) do
    %__MODULE__{
      effect: fn -> Task.async(fn -> %Either.Right{right: value} end) end
    }
  end
end

defimpl Funx.Monad, for: Funx.Effect.Right do
  alias Funx.Effect
  alias Effect.{Left, Right}
  alias Funx.Either

  @spec map(Right.t(right), (right -> result)) :: Right.t(result)
        when right: term(), result: term()
  def map(%Right{effect: effect}, mapper) do
    %Right{
      effect: fn ->
        Task.async(fn ->
          case Effect.run(%Right{effect: effect}) do
            %Either.Right{right: value} ->
              try do
                %Either.Right{right: mapper.(value)}
              rescue
                e -> %Either.Left{left: {:map_exception, e}}
              end

            %Either.Left{} = left ->
              left
          end
        end)
      end
    }
  end

  @spec ap(Right.t((right -> result)), Effect.t(left, right)) ::
          Effect.t(left, result)
        when left: term(), right: term(), result: term()
  def ap(%Right{effect: effect_func}, %Right{effect: effect_value}) do
    %Right{
      effect: fn ->
        Task.async(fn ->
          with %Either.Right{right: func} <- Effect.run(%Right{effect: effect_func}),
               %Either.Right{right: value} <- Effect.run(%Right{effect: effect_value}) do
            try do
              %Either.Right{right: func.(value)}
            rescue
              e -> %Either.Left{left: {:ap_exception, e}}
            end
          else
            %Either.Left{} = left -> left
          end
        end)
      end
    }
  end

  def ap(%Right{}, %Left{} = left), do: left

  @spec bind(Right.t(right), (right -> Effect.t(left, result))) ::
          Effect.t(left, result)
        when left: term(), right: term(), result: term()
  def bind(%Right{effect: effect}, binder) do
    %Right{
      effect: fn ->
        Task.async(fn ->
          case Effect.run(%Right{effect: effect}) do
            %Either.Right{right: value} ->
              binder.(value) |> Effect.run()

            %Either.Left{} = left ->
              left
          end
        end)
      end
    }
  end
end
