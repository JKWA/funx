defmodule Funx.Effect.Left do
  @moduledoc """
  Represents the `Left` variant of the `Effect` monad, used to model an error or failure in an asynchronous context.

  This module implements the following protocols:
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations within an effectful, lazy execution.
    - `String.Chars`: Provides a `to_string/1` function to represent `Left` values as strings.

  The `Left` effect propagates the wrapped error or failure without executing further success logic, supporting lazy, asynchronous tasks.
  """

  alias Funx.{Either, TraceContext}

  @enforce_keys [:effect, :trace]
  defstruct [:effect, :trace]

  @typedoc """
  Represents an asynchronous computation that produces a `Left` value.

  This type models an effectful computation that executes asynchronously, returning a `Task.t()`, which is expected to resolve to a `Left` value.
  """
  @type t(left) :: %__MODULE__{
          effect: (-> Task.t()) | (-> Either.Left.t(left)),
          trace: TraceContext.t()
        }

  @doc """
  Creates a new `Left` effect.

  The `pure/2` function wraps a value in the `Left` effect monad, representing an asynchronous error or failure.

  ## Examples

      iex> effect = Funx.Effect.Left.pure("error")
      iex> Funx.Effect.run(effect)
      %Funx.Either.Left{left: "error"}
  """
  @spec pure(left, keyword() | TraceContext.t()) :: t(left) when left: term()
  def pure(value, opts_or_trace \\ []) do
    trace =
      case opts_or_trace do
        %TraceContext{} = trace ->
          TraceContext.new(trace)

        opts when is_list(opts) ->
          trace = Keyword.get(opts, :trace, opts)
          TraceContext.new(trace)
      end

    %__MODULE__{
      effect: fn -> Task.async(fn -> %Either.Left{left: value} end) end,
      trace: trace
    }
  end
end

defimpl Funx.Monad, for: Funx.Effect.Left do
  alias Funx.TraceContext
  alias Funx.Effect
  alias Funx.Effect.Left

  @spec bind(Left.t(left), (any() -> Effect.t(left, result))) :: Left.t(left)
        when left: term(), result: term()
  def bind(%Left{effect: effect, trace: trace}, _binder) do
    promoted_trace = TraceContext.promote(trace, "bind")

    %Left{
      trace: promoted_trace,
      effect: fn ->
        Task.async(fn ->
          Task.await(effect.())
        end)
      end
    }
  end

  @spec map(Left.t(left), (right -> result)) :: Left.t(left)
        when left: term(), right: term(), result: term()
  def map(%Left{} = left, _mapper), do: left

  @spec ap(Left.t(left), Effect.t(left, right)) :: Left.t(left)
        when left: term(), right: term()
  def ap(%Left{effect: effect, trace: trace}, _other) do
    promoted_trace = TraceContext.promote(trace, "ap")
    %Left{effect: effect, trace: promoted_trace}
  end
end
