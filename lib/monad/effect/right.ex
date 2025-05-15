defmodule Funx.Effect.Right do
  @moduledoc """
  Represents the `Right` variant of the `Effect` monad, used to model a successful computation in an asynchronous context.

  This module implements the following protocols:
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions to handle monadic operations within an effectful, lazy execution context.
    - `String.Chars`: Provides a `to_string/1` function to represent `Right` values as strings.

  The `Right` effect allows the computation to proceed with successful values, supporting lazy, asynchronous tasks.
  """

  alias Funx.{Effect, Either}

  @enforce_keys [:effect, :env]
  defstruct [:effect, :env]

  @typedoc """
  Represents an asynchronous computation that produces a `Right` value.

  This type models an effectful computation that executes asynchronously, returning a `Task.t()`, which is expected to resolve to a `Right` value.
  """
  @type t(right) :: %__MODULE__{
          effect: (-> Task.t()) | (-> Either.Right.t(right)),
          env: Effect.Env.t()
        }

  @doc """
  Creates a new `Right` effect.

  The `pure/2` function wraps a value in the `Right` effect monad, representing an asynchronous success.

  ## Examples

      iex> effect = Funx.Effect.Right.pure("success")
      iex> Funx.Effect.run(effect)
      %Funx.Either.Right{right: "success"}
  """
  @spec pure(right, Effect.Env.opts_or_env()) :: t(right) when right: term()
  def pure(value, opts_or_env \\ []) do
    %__MODULE__{
      effect: fn -> Task.async(fn -> %Either.Right{right: value} end) end,
      env: Effect.Env.new(opts_or_env)
    }
  end
end

defimpl Funx.Monad, for: Funx.Effect.Right do
  alias Funx.{Effect, Either}
  alias Effect.{Left, Right}

  @spec map(Right.t(right), (right -> result)) :: Right.t(result)
        when right: term(), result: term()
  def map(%Right{effect: effect, env: env}, mapper) do
    updated_env = Effect.Env.promote_trace(env, "map")

    %Right{
      env: updated_env,
      effect: fn ->
        Task.async(fn ->
          case Effect.run(%Right{effect: effect, env: env}) do
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
  def ap(%Right{effect: effect_func, env: env_func}, %Right{
        effect: effect_value,
        env: env_val
      }) do
    merged_env = Effect.Env.merge(env_func, env_val)
    promoted_env = Effect.Env.promote_trace(merged_env, "ap")

    %Right{
      env: promoted_env,
      effect: fn ->
        Task.async(fn ->
          with %Either.Right{right: func} <-
                 Effect.run(%Right{effect: effect_func, env: env_func}),
               %Either.Right{right: value} <-
                 Effect.run(%Right{effect: effect_value, env: env_val}) do
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

  def ap(%Right{}, %Left{effect: eff, env: env}) do
    promoted_env = Effect.Env.promote_trace(env, "ap")
    %Left{effect: eff, env: promoted_env}
  end

  @spec bind(Right.t(right), (right -> Effect.t(left, result))) ::
          Effect.t(left, result)
        when left: term(), right: term(), result: term()
  def bind(%Right{effect: effect, env: env}, binder) do
    promoted_env = Effect.Env.promote_trace(env, "bind")

    %Right{
      env: promoted_env,
      effect: fn ->
        Task.async(fn ->
          case Effect.run(%Right{effect: effect, env: env}) do
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
