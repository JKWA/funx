defmodule Monex.Effect.Right do
  @moduledoc """
  Represents the `Right` variant of the `Effect` monad, used to model a successful computation in an asynchronous context.

  This module implements the following protocols:
    - `Monex.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions to handle monadic operations within an effectful, lazy execution context.
    - `String.Chars`: Provides a `to_string/1` function to represent `Right` values as strings.

  The `Right` effect allows the computation to proceed with successful values, supporting lazy, asynchronous tasks.
  """
  @enforce_keys [:effect]
  defstruct [:effect]

  @type t(right) :: %__MODULE__{effect: (-> Task.t(%Monex.Either.Right{value: right}))}

  @doc """
  Creates a new `Right` effect.

  The `pure/1` function wraps a value in the `Right` effect monad, representing an asynchronous success.

  ## Examples

      iex> Monex.Effect.Right.pure("success")
      %Monex.Effect.Right{
        effect: #Function<...>  # (an asynchronous task returning `Right`)
      }
  """
  @spec pure(right) :: t(right) when right: term()
  def pure(value) do
    %__MODULE__{
      effect: fn -> Task.async(fn -> %Monex.Either.Right{value: value} end) end
    }
  end

  defimpl Monex.Monad do
    alias Monex.Effect
    alias Effect.{Left, Right}
    alias Monex.Either

    @spec ap(Right.t((right -> result)), Effect.t(left, right)) ::
            Effect.t(left, result)
          when left: term(), right: term(), result: term()
    def ap(%Right{effect: effect_func}, %Right{effect: effect_value}) do
      %Right{
        effect: fn ->
          Task.async(fn ->
            %Either.Right{value: func} = Task.await(effect_func.())
            %Either.Right{value: value} = Task.await(effect_value.())
            %Either.Right{value: func.(value)}
          end)
        end
      }
    end

    def ap(_, %Left{} = left), do: left

    @spec bind(Right.t(right), (right -> Effect.t(left, result))) ::
            Effect.t(left, result)
          when left: term(), right: term(), result: term()
    def bind(%Right{effect: effect}, binder) do
      %Right{
        effect: fn ->
          Task.async(fn ->
            case Task.await(effect.()) do
              %Monex.Either.Right{value: value} ->
                case binder.(value) do
                  %Right{effect: next_effect} -> Task.await(next_effect.())
                  %Left{effect: next_effect} -> Task.await(next_effect.())
                end

              %Either.Left{value: left_value} ->
                %Either.Left{value: left_value}
            end
          end)
        end
      }
    end

    @spec map(Right.t(right), (right -> result)) :: Right.t(result)
          when right: term(), result: term()
    def map(%Right{effect: effect}, mapper) do
      %Right{
        effect: fn ->
          Task.async(fn ->
            case Task.await(effect.()) do
              %Either.Right{value: value} ->
                %Either.Right{value: mapper.(value)}

              %Either.Left{value: error} ->
                %Either.Left{value: error}
            end
          end)
        end
      }
    end
  end

  defimpl String.Chars do
    alias Monex.Effect.Right

    def to_string(%Right{effect: effect}) do
      "Right(#{Task.await(effect.())})"
    end
  end
end
