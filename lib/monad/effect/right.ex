defmodule Funx.Monad.Effect.Right do
  @moduledoc """
  Represents the `Right` variant of the `Effect` monad, used to model a successful computation in an asynchronous context.

  This module implements the following protocols:
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions to handle monadic operations within an effectful, lazy execution context.
    - `String.Chars`: Provides a `to_string/1` function to represent `Right` values as strings.

  The `Right` effect allows the computation to proceed with successful values, supporting lazy, asynchronous tasks
  and capturing execution context through the `Effect.Context` struct.

  ## Reader Operations

    * `ask/1` – Returns the environment passed to `run/2` as a `Right`.
    * `asks/2` – Applies a function to the environment passed to `run/2`, wrapping the result in a `Right`.
  """

  alias Funx.Monad.{Effect, Either}

  @enforce_keys [:effect, :context]
  defstruct [:effect, :context]

  @typedoc """
  Represents an asynchronous computation that produces a `Right` value.

  The `effect` function is typically a deferred task that takes an environment and returns a `Task`.
  Since Elixir does not support parameterized `Task.t()` types, the return type is described as a union:
  either a `Task.t()` or a plain `Either.Right.t(right)` for testability and flexibility.

  The `context` carries telemetry and trace information used during execution.
  """
  @type t(right) :: %__MODULE__{
          effect: (term() -> Task.t()) | (term() -> Either.Right.t(right)),
          context: Effect.Context.t()
        }

  @type t :: t(term())

  @doc """
  Creates a new `Right` effect.

  The `pure/2` function wraps a value in the `Right` effect monad, representing an asynchronous success.

  ## Examples

      iex> effect = Funx.Monad.Effect.Right.pure("success")
      iex> Funx.Monad.Effect.run(effect)
      %Funx.Monad.Either.Right{right: "success"}
  """
  @spec pure(right, Effect.Context.opts_or_context()) :: t(right)
        when right: term()
  def pure(value, opts_or_context \\ []) do
    %__MODULE__{
      context: Effect.Context.new(opts_or_context),
      effect: fn _env -> Task.async(fn -> Either.pure(value) end) end
    }
  end

  @doc """
  Returns a `Funx.Monad.Effect.Right` that yields the environment passed to `Funx.Monad.Effect.run/2`.

  This is the Reader monad's equivalent of `ask`, giving access to the entire injected environment
  for further computation.

  ## Example

      iex> Funx.Monad.Effect.Right.ask()
      ...> |> Funx.Monad.map(& &1[:user])
      ...> |> Funx.Monad.Effect.run(%{user: "alice"})
      %Funx.Monad.Either.Right{right: "alice"}
  """
  @spec ask(Effect.Context.opts_or_context()) :: t(env)
        when env: term()
  def ask(opts_or_context \\ []) do
    context = Effect.Context.new(opts_or_context)

    %__MODULE__{
      context: context,
      effect: fn env ->
        Task.async(fn -> Either.pure(env) end)
      end
    }
  end

  @doc """
  Returns a `Funx.Monad.Effect.Right` that applies the given function to the environment passed to `Funx.Monad.Effect.run/2`.

  This allows extracting a value from the environment and using it in an effectful computation,
  following the Reader pattern.

  ## Example

      iex> Funx.Monad.Effect.Right.asks(fn env -> env[:user] end)
      ...> |> Funx.Monad.bind(fn user -> Funx.Monad.Effect.right(user) end)
      ...> |> Funx.Monad.Effect.run(%{user: "alice"})
      %Funx.Monad.Either.Right{right: "alice"}
  """

  @spec asks((Effect.Context.t() -> result), Effect.Context.opts_or_context()) :: t(result)
        when result: term()
  def asks(f, opts_or_context \\ []) do
    context = Effect.Context.new(opts_or_context)

    %__MODULE__{
      context: context,
      effect: fn env ->
        Task.async(fn -> Either.pure(f.(env)) end)
      end
    }
  end
end

defimpl Funx.Monad, for: Funx.Monad.Effect.Right do
  alias Funx.Errors.EffectError
  alias Funx.Monad.{Effect, Either}
  alias Effect.{Left, Right}

  @spec map(Right.t(input), (input -> output)) :: Right.t(output)
        when input: term(), output: term()
  def map(%Right{effect: effect, context: context}, transform) do
    updated_context = Effect.Context.promote_trace(context, "map")

    %Right{
      context: updated_context,
      effect: fn env ->
        Task.async(fn ->
          case Effect.run(%Right{effect: effect, context: context}, env) do
            %Either.Right{right: value} ->
              try do
                Either.pure(transform.(value))
              rescue
                e -> Either.left(EffectError.new(:map, e))
              end

            %Either.Left{} = left ->
              left
          end
        end)
      end
    }
  end

  @spec bind(Right.t(input), (input -> Effect.t(left, output))) :: Effect.t(left, output)
        when input: term(), output: term(), left: term()
  def bind(%Right{effect: effect, context: context}, kleisli_fn) do
    promoted_context = Effect.Context.promote_trace(context, "bind")

    %Right{
      context: promoted_context,
      effect: fn env ->
        Task.async(fn ->
          case Effect.run(%Right{effect: effect, context: context}, env) do
            %Either.Right{right: value} ->
              try do
                next = kleisli_fn.(value)
                Effect.run(next, env)
              rescue
                e -> Either.left(EffectError.new(:bind, e))
              end

            %Either.Left{} = left ->
              left
          end
        end)
      end
    }
  end

  @spec ap(Right.t((input -> output)), Right.t(input)) :: Right.t(output)
        when input: term(), output: term()

  @spec ap(Right.t(), Left.t(left)) :: Left.t(left)
        when left: term()
  def ap(%Right{effect: effect_func, context: context_func}, %Right{
        effect: effect_value,
        context: context_val
      }) do
    merged_context = Effect.Context.merge(context_func, context_val)
    promoted_context = Effect.Context.promote_trace(merged_context, "ap")

    %Right{
      context: promoted_context,
      effect: fn env ->
        Task.async(fn ->
          with %Either.Right{right: func} <-
                 Effect.run(%Right{effect: effect_func, context: context_func}, env),
               %Either.Right{right: value} <-
                 Effect.run(%Right{effect: effect_value, context: context_val}, env) do
            try do
              Either.pure(func.(value))
            rescue
              e -> Either.left(EffectError.new(:ap, e))
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

    %Left{
      context: promoted_context,
      effect: fn env -> eff.(env) end
    }
  end

  defimpl Funx.Tappable, for: Funx.Monad.Either.Right do
    alias Funx.Monad.Either.Right

    @spec tap(Right.t(value), (value -> any())) :: Right.t(value)
          when value: term()
    def tap(%{right: value} = right, fun) do
      fun.(value)
      right
    end
  end
end
