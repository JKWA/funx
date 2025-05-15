defmodule Funx.Effect.Env do
  @moduledoc """
  Represents the environment passed to effectful computations.

  This struct carries contextual information such as `trace_id`, `span_name`,
  timeouts, and arbitrary metadata (`baggage`). It supports telemetry, span
  linking, and execution control in a composable and extensible way.

  The environment can be constructed from a keyword list or another `%Effect.Env{}` struct,
  and merged or promoted to represent nested operations within an effect chain.
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

  @type opts_or_env :: keyword() | t()

  @doc """
  Creates a new `Effect.Env` struct for use with effectful computations.

  If no `:trace_id` is provided, a new one is generated automatically.
  Additional fields like `:span_name`, `:timeout`, and `:baggage` can also be set.

  ## Examples

      iex> env = Funx.Effect.Env.new(span_name: "load-data", timeout: 2000)
      iex> env.span_name
      "load-data"

      iex> env = Funx.Effect.Env.new(trace_id: "abc123")
      iex> env.trace_id
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
  Merges two trace contexts into one, preferring non-nil values from the first context.

  Baggage maps are merged together. This is useful when combining multiple effect traces.

  ## Examples

      iex> c1 = Funx.Effect.Env.new(trace_id: "a", baggage: %{user: 1})
      iex> c2 = Funx.Effect.Env.new(trace_id: "b", baggage: %{region: "us-west"})
      iex> Funx.Effect.Env.merge(c1, c2).baggage
      %{user: 1, region: "us-west"}
  """
  @spec merge(t(), t()) :: t()
  def merge(env1, env2) do
    %__MODULE__{
      trace_id: env1.trace_id || env2.trace_id,
      parent_trace_id: env1.parent_trace_id || env2.parent_trace_id,
      span_name: env1.span_name || env2.span_name,
      timeout: env1.timeout || env2.timeout,
      baggage: Map.merge(env2.baggage || %{}, env1.baggage || %{}),
      metadata: Map.merge(env2.metadata || %{}, env1.metadata || %{})
    }
  end

  @doc """
  Returns a new environment with values from the given keyword list overriding the existing ones.

  Fields like `:trace_id`, `:parent_trace_id`, `:span_name`, and `:timeout` are directly replaced if present.
  For `:baggage` and `:metadata`, maps are deep-merged with the keyword list taking precedence.

  ## Examples

      iex> env = Funx.Effect.Env.new(trace_id: "abc", baggage: %{x: 1}, metadata: %{debug: false})
      iex> updated = Funx.Effect.Env.override(env, span_name: "child", baggage: %{x: 2}, metadata: %{debug: true})
      iex> updated.span_name
      "child"
      iex> updated.baggage
      %{x: 2}
      iex> updated.metadata
      %{debug: true}
  """
  @spec override(t(), keyword()) :: t()
  def override(%__MODULE__{} = env, opts) when is_list(opts) do
    %__MODULE__{
      trace_id: Keyword.get(opts, :trace_id, env.trace_id),
      parent_trace_id: Keyword.get(opts, :parent_trace_id, env.parent_trace_id),
      span_name: Keyword.get(opts, :span_name, env.span_name),
      timeout: Keyword.get(opts, :timeout, env.timeout),
      baggage: Map.merge(env.baggage || %{}, Keyword.get(opts, :baggage, %{})),
      metadata: Map.merge(env.metadata || %{}, Keyword.get(opts, :metadata, %{}))
    }
  end

  @doc """
  Creates a new trace context by promoting the current environment into a child trace.

  Generates a fresh `trace_id`, assigns the original as `parent_trace_id`, and prepends the given `label`
  to the existing `span_name`. This is typically used to represent a nested operation or span
  within a larger effectful computation.

  ## Examples

      iex> parent = Funx.Effect.Env.new(trace_id: "abc123", span_name: "load")
      iex> child = Funx.Effect.Env.promote_trace(parent, "decode")
      iex> child.parent_trace_id
      "abc123"
      iex> child.trace_id != "abc123"
      true
      iex> child.span_name
      "decode -> load"
  """
  @spec promote_trace(t(), String.t()) :: t()
  def promote_trace(%__MODULE__{} = env, label) do
    %__MODULE__{
      trace_id: generate_trace_id(),
      parent_trace_id: env.trace_id,
      span_name: "#{label} -> #{env.span_name || Funx.Config.default_span_name()}",
      timeout: env.timeout,
      baggage: env.baggage,
      metadata: env.metadata
    }
  end

  @doc """
  Generates a random lowercase hexadecimal trace ID.

  This function is used internally to ensure each trace is uniquely identifiable.

  ## Examples

      iex> id = Funx.Effect.Env.generate_trace_id()
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

  def empty_or_default_span_name?(%__MODULE__{} = env) do
    Predicate.p_any([
      Predicate.p_not(&span_name?/1),
      &default_span_name?/1
    ]).(env)
  end

  def default_span_name_if_empty(%__MODULE__{} = env, default_name) do
    fold_l(
      fn -> Predicate.p_not(&empty_or_default_span_name?/1).(env) end,
      fn -> env end,
      fn -> %__MODULE__{env | span_name: default_name} end
    )
  end
end
