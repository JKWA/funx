defmodule Funx.TraceContext do
  @moduledoc """
  Represents trace-related context for effectful operations.
  Used for telemetry, span linking, and cross-process trace propagation.
  """

  import Funx.Foldable, only: [fold_l: 3]
  alias Funx.Predicate

  @enforce_keys [:trace_id]
  defstruct [
    :trace_id,
    :parent_trace_id,
    :span_name,
    :timeout,
    :baggage
  ]

  @type t :: %__MODULE__{
          trace_id: String.t(),
          parent_trace_id: String.t() | nil,
          span_name: String.t() | nil,
          timeout: non_neg_integer() | nil,
          baggage: map() | nil
        }

  @type opts_or_trace :: keyword() | t()

  @doc """
  Creates a new `TraceContext` struct for use with effectful computations.

  If no `:trace_id` is provided, a new one is generated automatically.
  Additional fields like `:span_name`, `:timeout`, and `:baggage` can also be set.

  ## Examples

      iex> ctx = Funx.TraceContext.new(span_name: "load-data", timeout: 2000)
      iex> ctx.span_name
      "load-data"

      iex> ctx = Funx.TraceContext.new(trace_id: "abc123")
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
      baggage: Keyword.get(fields, :baggage)
    }
  end

  @doc """
  Merges two trace contexts into one, preferring non-nil values from the first context.

  Baggage maps are merged together. This is useful when combining multiple effect traces.

  ## Examples

      iex> c1 = Funx.TraceContext.new(trace_id: "a", baggage: %{user: 1})
      iex> c2 = Funx.TraceContext.new(trace_id: "b", baggage: %{region: "us-west"})
      iex> Funx.TraceContext.merge(c1, c2).baggage
      %{user: 1, region: "us-west"}
  """
  @spec merge(t(), t()) :: t()
  def merge(ctx1, ctx2) do
    %__MODULE__{
      trace_id: ctx1.trace_id || ctx2.trace_id,
      parent_trace_id: ctx1.parent_trace_id || ctx2.parent_trace_id,
      span_name: ctx1.span_name || ctx2.span_name,
      timeout: ctx1.timeout || ctx2.timeout,
      baggage: Map.merge(ctx1.baggage || %{}, ctx2.baggage || %{})
    }
  end

  @doc """
  Promotes a trace to a new context with a fresh `trace_id`, linking the original as `parent_trace_id`.

  This is commonly used when starting a new span or sub-operation under an existing trace.

  ## Examples

      iex> parent = Funx.TraceContext.new(trace_id: "abc123", span_name: "load")
      iex> child = Funx.TraceContext.promote(parent, "decode")
      iex> child.parent_trace_id
      "abc123"
      iex> String.starts_with?(child.span_name, "decode -> ")
      true
  """
  @spec promote(t(), String.t()) :: t()
  def promote(%__MODULE__{} = ctx, label) do
    %__MODULE__{
      trace_id: generate_trace_id(),
      parent_trace_id: ctx.trace_id,
      span_name: "#{label} -> #{ctx.span_name || Funx.Config.default_span_name()}",
      timeout: ctx.timeout,
      baggage: ctx.baggage
    }
  end

  @doc """
  Generates a random lowercase hexadecimal trace ID.

  This function is used internally to ensure each trace is uniquely identifiable.

  ## Examples

      iex> id = Funx.TraceContext.generate_trace_id()
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

  def empty_or_default_span_name?(%__MODULE__{} = ctx) do
    Predicate.p_any([
      Predicate.p_not(&span_name?/1),
      &default_span_name?/1
    ]).(ctx)
  end

  def default_span_name_if_empty(%__MODULE__{} = ctx, default_name) do
    fold_l(
      fn -> Predicate.p_not(&empty_or_default_span_name?/1).(ctx) end,
      fn -> ctx end,
      fn -> %__MODULE__{ctx | span_name: default_name} end
    )
  end
end
