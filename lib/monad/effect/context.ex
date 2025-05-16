defmodule Funx.Effect.Context do
  @moduledoc """
  Represents the execution context attached to an effect.

  This struct carries contextual information such as `trace_id`, `span_name`,
  timeouts, and arbitrary metadata (`baggage` and `metadata`). It supports
  telemetry integration, span linking, and timeout control, and is propagated
  automatically across composed effects.

  Developers can set fields like `timeout`, `trace_id`, or `span_name` when
  constructing `Left` and `Right` effects. The context is merged or promoted
  as needed when chaining effects to preserve trace continuity and execution scope.

  This context is not injected at runtime via `run/2`—it is bound to the effect
  when created.
  """

  import Funx.Foldable, only: [fold_l: 3]
  alias Funx.Predicate

  @enforce_keys [:trace_id]
  defstruct [
    :trace_id,
    :parent_trace_id,
    :span_name,
    :timeout,
    baggage: %{},
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          trace_id: String.t(),
          parent_trace_id: String.t() | nil,
          span_name: String.t() | nil,
          timeout: non_neg_integer() | nil,
          baggage: map() | nil,
          metadata: map() | nil
        }

  @type opts_or_trace :: keyword() | t()

  @doc """
  Creates a new `Funx.Effect.Context` struct for use with effectful computations.

  If no `:trace_id` is provided, a unique one is generated automatically.
  You may also set optional fields such as `:span_name`, `:timeout`, `:baggage`, and `:metadata`.

  The returned context is intended to be passed into `Left` and `Right` effects,
  where it will be propagated and updated across chained computations.

  ## Examples

      iex> ctx = Funx.Effect.Context.new(span_name: "load-data", timeout: 2000)
      iex> ctx.span_name
      "load-data"

      iex> ctx = Funx.Effect.Context.new(trace_id: "abc123")
      iex> ctx.trace_id
      "abc123"
  """
  @spec new(keyword() | t()) :: t()
  def new, do: new([])

  def new(%__MODULE__{} = trace) do
    %__MODULE__{
      trace_id: trace.trace_id || generate_trace_id(),
      parent_trace_id: trace.parent_trace_id,
      span_name: trace.span_name || Funx.Config.default_span_name(),
      timeout: trace.timeout,
      baggage: trace.baggage
    }
  end

  def new(fields) when is_list(fields) do
    trace_id = Keyword.get(fields, :trace_id, generate_trace_id())
    span_name = Keyword.get(fields, :span_name, Funx.Config.default_span_name())

    %__MODULE__{
      trace_id: trace_id,
      parent_trace_id: Keyword.get(fields, :parent_trace_id),
      span_name: span_name,
      timeout: Keyword.get(fields, :timeout),
      baggage: Keyword.get(fields, :baggage, %{}),
      metadata: Keyword.get(fields, :metadata, %{})
    }
  end

  @doc """
  Merges two `%Funx.Effect.Context{}` structs into one, preferring non-nil values from the first context.

  This is used to preserve trace continuity and propagate context across composed effects.

  - Non-nil fields from the first context take precedence.
  - `baggage` and `metadata` maps are deeply merged.
  - This operation is idempotent and safe for reuse across nested effect chains.

  ## Examples

      iex> c1 = Funx.Effect.Context.new(trace_id: "a", baggage: %{user: 1})
      iex> c2 = Funx.Effect.Context.new(trace_id: "b", baggage: %{region: "us-west"})
      iex> Funx.Effect.Context.merge(c1, c2).baggage
      %{user: 1, region: "us-west"}
  """
  @spec merge(t(), t()) :: t()
  def merge(context1, context2) do
    %__MODULE__{
      trace_id: context1.trace_id || context2.trace_id,
      parent_trace_id: context1.parent_trace_id || context2.parent_trace_id,
      span_name: context1.span_name || context2.span_name,
      timeout: context1.timeout || context2.timeout,
      baggage: Map.merge(context2.baggage || %{}, context1.baggage || %{}),
      metadata: Map.merge(context2.metadata || %{}, context1.metadata || %{})
    }
  end

  @doc """
  Returns a new `%Funx.Effect.Context{}` with fields overridden by values from the given keyword list.

  - Direct fields like `:trace_id`, `:parent_trace_id`, `:span_name`, and `:timeout` are replaced if present.
  - Nested maps `:baggage` and `:metadata` are deeply merged, with the keyword list taking precedence.

  This is useful for refining or extending an existing context in a specific part of an effect chain.

  ## Examples

      iex> ctx = Funx.Effect.Context.new(trace_id: "abc", baggage: %{x: 1}, metadata: %{debug: false})
      iex> updated = Funx.Effect.Context.override(ctx, span_name: "child", baggage: %{x: 2}, metadata: %{debug: true})
      iex> updated.span_name
      "child"
      iex> updated.baggage
      %{x: 2}
      iex> updated.metadata
      %{debug: true}
  """
  @spec override(t(), keyword()) :: t()
  def override(%__MODULE__{} = context, opts) when is_list(opts) do
    %__MODULE__{
      trace_id: Keyword.get(opts, :trace_id, context.trace_id),
      parent_trace_id: Keyword.get(opts, :parent_trace_id, context.parent_trace_id),
      span_name: Keyword.get(opts, :span_name, context.span_name),
      timeout: Keyword.get(opts, :timeout, context.timeout),
      baggage: Map.merge(context.baggage || %{}, Keyword.get(opts, :baggage, %{})),
      metadata: Map.merge(context.metadata || %{}, Keyword.get(opts, :metadata, %{}))
    }
  end

  @doc """
  Promotes the current context into a child trace by generating a new `trace_id` and linking to the original.

  - The current `trace_id` is moved to `parent_trace_id`.
  - A new `trace_id` is generated for the child context.
  - The given `label` is prepended to the existing `span_name` as `"label -> span"`.

  This is typically used to represent a nested span or sub-operation within a larger effect chain,
  preserving trace lineage across composed effects.

  ## Examples

      iex> parent = Funx.Effect.Context.new(trace_id: "abc123", span_name: "load")
      iex> child = Funx.Effect.Context.promote_trace(parent, "decode")
      iex> child.parent_trace_id
      "abc123"
      iex> child.trace_id != "abc123"
      true
      iex> child.span_name
      "decode -> load"
  """
  @spec promote_trace(t(), String.t()) :: t()
  def promote_trace(%__MODULE__{} = context, label) do
    %__MODULE__{
      trace_id: generate_trace_id(),
      parent_trace_id: context.trace_id,
      span_name: "#{label} -> #{context.span_name || Funx.Config.default_span_name()}",
      timeout: context.timeout,
      baggage: context.baggage,
      metadata: context.metadata
    }
  end

  @doc """
  Generates a random lowercase hexadecimal trace ID.

  This function is used internally to ensure each trace is uniquely identifiable.

  ## Examples

      iex> id = Funx.Effect.Context.generate_trace_id()
      iex> String.length(id)
      32
      iex> id =~ ~r/^[a-f0-9]+$/
      true
  """
  @spec generate_trace_id() :: String.t()
  def generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  def span_name?(%__MODULE__{span_name: nil}), do: false
  def span_name?(%__MODULE__{}), do: true

  def default_span_name?(%__MODULE__{span_name: name}),
    do: name == Funx.Config.default_span_name()

  def empty_or_default_span_name?(%__MODULE__{} = context) do
    Predicate.p_any([
      Predicate.p_not(&span_name?/1),
      &default_span_name?/1
    ]).(context)
  end

  def default_span_name_if_empty(%__MODULE__{} = context, default_name) do
    fold_l(
      fn -> Predicate.p_not(&empty_or_default_span_name?/1).(context) end,
      fn -> context end,
      fn -> %__MODULE__{context | span_name: default_name} end
    )
  end
end
