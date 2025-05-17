defmodule Funx.Effect.Left do
  @moduledoc """
  Represents the `Left` variant of the `Effect` monad, used to model a failure or error in an asynchronous context.

  This module implements the following protocols:
    - `Funx.Monad`: Implements `bind/2`, `map/2`, and `ap/2` for monadic sequencing in a lazy, effectful context.
    - `String.Chars`: Provides a string representation of the effect for debugging and inspection.

  A `Left` effect propagates its failure value without invoking further computations, preserving short-circuit behavior.

  ## Reader Operations

    * `ask/1` – Returns the environment passed to `run/2` as a `Left`.
    * `asks/2` – Applies a function to the environment passed to `run/2`, wrapping the result in a `Left`.
  """

  alias Funx.{Effect, Either}

  @enforce_keys [:effect, :context]
  defstruct [:effect, :context]

  @typedoc """
  Represents an asynchronous computation that produces a `Left` value.

  The `effect` function is typically a deferred task that takes an environment and returns a `Task`.
  Since Elixir does not support parameterized `Task.t()` types, the return type is written as a union:
  either a `Task.t()` or a plain `Either.Left.t(left)` to support testing and internal optimizations.

  The `context` carries telemetry, trace metadata, and environment configuration for error flows.
  """
  @type t(left) :: %__MODULE__{
          effect: (term() -> Task.t()) | (term() -> Either.Left.t(left)),
          context: Effect.Context.t()
        }

  @type t :: t(term())

  @doc """
  Creates a new `Left` effect.

  Wraps a failure value in an asynchronous effect. You may provide context either as a keyword list or
  an `Effect.Context` struct.

  ## Examples

      iex> effect = Funx.Effect.Left.pure("error")
      iex> Funx.Effect.run(effect)
      %Funx.Either.Left{left: "error"}
  """
  @spec pure(left, Effect.Context.opts_or_context()) :: t(left)
        when left: term()
  def pure(value, opts_or_context \\ []) do
    context = Effect.Context.new(opts_or_context)

    %__MODULE__{
      context: context,
      effect: fn _env -> Task.async(fn -> %Either.Left{left: value} end) end
    }
  end

  @doc """
  Returns a `Funx.Effect.Left` that yields the environment passed to `Funx.Effect.run/2`.

  This is the Reader-style `ask`, used to construct a failure from the full injected environment.
  It can be useful for debugging, instrumentation, or propagating request-scoped failure information.

  ## Example

      iex> Funx.Effect.Left.ask()
      ...> |> Funx.Effect.run(%{error: :unauthorized})
      %Funx.Either.Left{left: %{error: :unauthorized}}
  """
  @spec ask(Effect.Context.opts_or_context()) :: t(env)
        when env: term()
  def ask(opts_or_context \\ []) do
    context = Effect.Context.new(opts_or_context)

    %__MODULE__{
      context: context,
      effect: fn env ->
        Task.async(fn -> %Either.Left{left: env} end)
      end
    }
  end

  @doc """
  Returns a `Funx.Effect.Left` that applies the given function to the environment passed to `Funx.Effect.run/2`.

  This allows constructing a failure (`Left`) based on runtime input. It complements `Right.asks/2`,
  but marks the result as a failure rather than a success.

  ## Example

      iex> Funx.Effect.Left.asks(fn env -> {:error, env[:reason]} end)
      ...> |> Funx.Effect.run(%{reason: :invalid})
      %Funx.Either.Left{left: {:error, :invalid}}
  """
  @spec asks((env -> left), Effect.Context.opts_or_context()) :: t(left)
        when env: term(), left: term()
  def asks(f, opts_or_context \\ []) do
    context = Effect.Context.new(opts_or_context)

    %__MODULE__{
      context: context,
      effect: fn env ->
        Task.async(fn -> %Either.Left{left: f.(env)} end)
      end
    }
  end
end

defimpl Funx.Monad, for: Funx.Effect.Left do
  alias Funx.Effect
  alias Funx.Effect.Left

  @spec bind(Left.t(left), (term() -> Effect.t(left, result))) :: Left.t(left)
        when left: term(), result: term()
  def bind(%Left{effect: effect, context: context}, _binder) do
    %Left{
      context: context,
      effect: fn env -> effect.(env) end
    }
  end

  @spec map(Left.t(left), (term() -> term())) :: Left.t(left)
        when left: term()
  def map(%Left{effect: effect, context: context}, _mapper) do
    %Left{
      context: context,
      effect: fn env -> effect.(env) end
    }
  end

  @spec ap(Left.t(left), Effect.t(left, any())) :: Left.t(left)
        when left: term()
  def ap(%Left{effect: effect, context: context}, _other) do
    %Left{
      context: context,
      effect: fn env -> effect.(env) end
    }
  end
end
