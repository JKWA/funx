defmodule Funx.Effect.Right do
  @moduledoc """
  Represents the `Right` variant of the `Effect` monad, used to model a successful computation in an asynchronous context.

  This module implements the following protocols:
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions to handle monadic operations within an effectful, lazy execution context.
    - `String.Chars`: Provides a `to_string/1` function to represent `Right` values as strings.

  The `Right` effect allows the computation to proceed with successful values, supporting lazy, asynchronous tasks.
  """

  alias Funx.{Effect, Either}

  @enforce_keys [:effect, :context]
  defstruct [:effect, :context]

  @typedoc """
  Represents an asynchronous computation that produces a `Right` value.

  This type models an effectful computation that executes asynchronously, returning a `Task.t()`, which is expected to resolve to a `Right` value.
  """
  @type t(right) :: %__MODULE__{
          effect: (-> Task.t()) | (-> Either.Right.t(right)),
          context: Effect.Context.t()
        }

  @doc """
  Creates a new `Right` effect.

  The `pure/2` function wraps a value in the `Right` effect monad, representing an asynchronous success.

  ## Examples

      iex> effect = Funx.Effect.Right.pure("success")
      iex> Funx.Effect.run(effect)
      %Funx.Either.Right{right: "success"}
  """
  @spec pure(right, Effect.Context.opts_or_trace()) :: t(right) when right: term()
  def pure(value, opts_or_trace \\ []) do
    %__MODULE__{
      effect: fn -> Task.async(fn -> %Either.Right{right: value} end) end,
      context: Effect.Context.new(opts_or_trace)
    }
  end
end

defimpl Funx.Monad, for: Funx.Effect.Right do
  alias Funx.{Effect, Either}
  alias Effect.{Left, Right}

  @spec map(Right.t(right), (right -> result)) :: Right.t(result)
        when right: term(), result: term()
  def map(%Right{effect: effect, context: context}, mapper) do
    updated_context = Effect.Context.promote_trace(context, "map")

    %Right{
      context: updated_context,
      effect: fn ->
        Task.async(fn ->
          case Effect.run(%Right{effect: effect, context: context}) do
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
  def ap(%Right{effect: effect_func, context: context_func}, %Right{
        effect: effect_value,
        context: context_val
      }) do
    merged_context = Effect.Context.merge(context_func, context_val)
    promoted_context = Effect.Context.promote_trace(merged_context, "ap")

    %Right{
      context: promoted_context,
      effect: fn ->
        Task.async(fn ->
          with %Either.Right{right: func} <-
                 Effect.run(%Right{effect: effect_func, context: context_func}),
               %Either.Right{right: value} <-
                 Effect.run(%Right{effect: effect_value, context: context_val}) do
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

  def ap(%Right{}, %Left{effect: eff, context: context}) do
    promoted_context = Effect.Context.promote_trace(context, "ap")
    %Left{effect: eff, context: promoted_context}
  end

  @spec bind(Right.t(right), (right -> Effect.t(left, result))) ::
          Effect.t(left, result)
        when left: term(), right: term(), result: term()
  def bind(%Right{effect: effect, context: context}, binder) do
    promoted_context = Effect.Context.promote_trace(context, "bind")

    %Right{
      context: promoted_context,
      effect: fn ->
        Task.async(fn ->
          case Effect.run(%Right{effect: effect, context: context}) do
            %Either.Right{right: value} ->
              next = binder.(value)
              Effect.run(next)

            %Either.Left{} = left ->
              left
          end
        end)
      end
    }
  end
end
