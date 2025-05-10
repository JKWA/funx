defmodule Funx.Effect do
  @moduledoc """
  The `Funx.Effect` module defines the `Effect` monad, which represents asynchronous computations
  that may succeed (`Right`) or fail (`Left`). Execution is deferred until explicitly run, making
  `Effect` useful for structuring lazy, asynchronous workflows.

  ## Constructors

    * `right/1` – Wraps a value in a successful `Right` effect.
    * `left/1` – Wraps a value in a failing `Left` effect.
    * `pure/1` – Alias for `right/1`.

  ## Execution

    * `run/2` – Executes the deferred effect and returns an `Either` result (`Right` or `Left`).

  ## Sequencing

    * `sequence/1` – Runs a list of effects, stopping at the first `Left`.
    * `traverse/2` – Applies a function returning an `Effect` to each element of a list, sequencing results.
    * `sequence_a/1` – Runs a list of effects, collecting all `Left` errors instead of short-circuiting.
    * `traverse_a/2` – Like `traverse/2`, but accumulates errors across the list.

  ## Validation

    * `validate/2` – Validates a value using one or more effectful validators.

  ## Lifting

    * `lift_either/1` – Lifts an `Either` value into an `Effect`.
    * `lift_maybe/2` – Lifts a `Maybe` into an `Effect`, using a fallback error for `Nothing`.
    * `lift_predicate/3` – Lifts a predicate into an `Effect`, using a provided fallback on failure.

  ## Elixir Interop

    * `from_result/1` – Converts a `{:ok, _}` or `{:error, _}` tuple into an `Effect`.
    * `to_result/1` – Converts an `Effect` to `{:ok, _}` or `{:error, _}`.
    * `from_try/1` – Executes a function, catching exceptions into a `Left`.
    * `to_try!/1` – Extracts the value from a `Right`, or raises an exception if `Left`.

  ## Telemetry

  The `run/2` function emits telemetry using `:telemetry.span/3`.

  ### Events

    * `[:funx, :effect, :run, :start]`
    * `[:funx, :effect, :run, :stop]`

  ### Measurements

    * `:monotonic_time` – included in both `:start` and `:stop` events.
    * `:system_time` – included only in the `:start` event.
    * `:duration` – included only in the `:stop` event.

  ### Metadata

    * `:timeout` – the timeout in milliseconds passed to `run/2`.
    * `:result` – a summarized version of the result using `Funx.Summarizable`.
    * `:effect_type` – `:right` or `:left`, depending on the effect being run.
    * `:status` – `:ok` if the result is a `Right`, or `:error` if it's a `Left`.
    * `:trace_id` – optional value used to correlate traces across boundaries.
    * `:span_name` – optional name for the span (defaults to `"funx.effect.run"`).
    * `:telemetry_span_context` – reference to correlate `:start` and `:stop` events.

  ### Example

  ```elixir
  :telemetry.attach(
    "effect-run-handler",
    [:funx, :effect, :run, :stop],
    fn event, measurements, metadata, _config ->
      IO.inspect({event, measurements, metadata}, label: "Effect telemetry")
    end,
    nil
  )
  ```
  """

  import Funx.Monad, only: [map: 2]
  import Funx.Foldable, only: [fold_l: 3]

  alias Funx.{Effect, Either, Maybe}
  alias Effect.{Left, Right}
  alias Funx.TraceContext
  alias Maybe.{Just, Nothing}

  @type t(left, right) :: Left.t(left) | Right.t(right)

  @doc """
  Wraps a value in the `Right` variant of the `Effect` monad, representing a successful asynchronous computation.

  This is an alias for `pure/2`. It accepts either a keyword list of trace options or a `TraceContext` struct.

  ## Examples

      iex> result = Funx.Effect.right(42)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}

      iex> trace = Funx.TraceContext.new(trace_id: "custom-id", span_name: "from right")
      iex> result = Funx.Effect.right(42, trace)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}
  """
  @spec right(right, TraceContext.opts_or_trace()) :: t(term(), right) when right: term()
  def right(value, opts_or_trace \\ []), do: pure(value, opts_or_trace)

  @doc """
  Alias for `right/2`.

  Wraps a value in the `Right` variant of the `Effect` monad, representing a successful asynchronous computation.

  Accepts either a keyword list of trace options or a `TraceContext` struct.

  ## Examples

      iex> result = Funx.Effect.pure(42)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}

      iex> trace = Funx.TraceContext.new(trace_id: "custom-id", span_name: "pure example")
      iex> result = Funx.Effect.pure(42, trace)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}
  """
  @spec pure(right, TraceContext.opts_or_trace()) :: t(term(), right) when right: term()
  def pure(value, opts_or_trace \\ []), do: Right.pure(value, opts_or_trace)

  @doc """
  Wraps a value in the `Left` variant of the `Effect` monad, representing a failed asynchronous computation.

  Accepts either a keyword list of trace options or a `TraceContext` struct.

  ## Examples

      iex> result = Funx.Effect.left("error")
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "error"}

      iex> trace = Funx.TraceContext.new(trace_id: "err-id", span_name: "failure")
      iex> result = Funx.Effect.left("error", trace)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "error"}
  """
  @spec left(left, TraceContext.opts_or_trace()) :: t(left, term()) when left: term()
  def left(value, opts_or_trace \\ []), do: Left.pure(value, opts_or_trace)

  @doc """
  Runs the `Effect` effect and returns the result, awaiting the effect if necessary.

  ## Examples

      iex> result = Funx.Effect.right(42)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}
  """
  @spec run(t(left, right), TraceContext.t() | nil) :: Either.t(left, right)
        when left: term(), right: term()
  def run(%{trace: %TraceContext{} = internal_trace} = effect, external_trace \\ nil)
      when is_struct(effect, Effect.Right) or is_struct(effect, Effect.Left) do
    trace = external_trace || internal_trace

    timeout = trace.timeout || Funx.Config.timeout()
    span_name = trace.span_name || Funx.Config.default_span_name()

    prefix = Funx.Config.telemetry_prefix() ++ [:effect, :run]

    if Funx.Config.telemetry_enabled?() do
      :telemetry.span(prefix, %{timeout: timeout, span_name: span_name}, fn ->
        result = execute_effect(effect, timeout)
        {result, build_metadata(%{effect | trace: trace}, result, trace)}
      end)
    else
      execute_effect(effect, timeout)
    end
  end

  defp execute_effect(%Right{effect: eff}, timeout), do: safe_await(eff.(), timeout)
  defp execute_effect(%Left{effect: eff}, timeout), do: safe_await(eff.(), timeout)

  defp build_metadata(effect, result, %TraceContext{} = trace) do
    %{
      result: Funx.Config.summarizer().(result),
      effect_type: if(match?(%Either.Right{}, result), do: :right, else: :left),
      status: if(match?(%Either.Right{}, result), do: :ok, else: :error),
      span_name: trace.span_name,
      trace_id: trace.trace_id
    }
    |> maybe_put_parent_trace_id(effect)
  end

  defp maybe_put_parent_trace_id(meta, %{trace: %TraceContext{parent_trace_id: nil}}), do: meta

  defp maybe_put_parent_trace_id(meta, %{trace: %TraceContext{parent_trace_id: pid}}),
    do: Map.put(meta, :parent_trace_id, pid)

  @spec safe_await(Task.t(), timeout()) :: Either.t(any(), any())
  def safe_await(task, timeout \\ 5000) do
    try do
      case Task.yield(task, timeout) || Task.shutdown(task) do
        {:ok, %Either.Right{} = right} -> right
        {:ok, %Either.Left{} = left} -> left
        {:ok, other} -> %Either.Left{left: {:invalid_result, other}}
        nil -> %Either.Left{left: :timeout}
      end
    rescue
      error -> %Either.Left{left: {:exception, error}}
    end
  end

  @doc """
  Lifts a value into the `Effect` monad based on a predicate.
  If the predicate returns true, the value is wrapped in `Right`.
  Otherwise, the result of calling `on_false` with the value is wrapped in `Left`.

  Optional trace metadata (e.g. `:span_name`, `:trace_id`) can be passed via `opts`.

  ## Examples

      iex> result = Funx.Effect.lift_predicate(10, &(&1 > 5), fn x -> "\#{x} is too small" end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 10}

      iex> result = Funx.Effect.lift_predicate(3, &(&1 > 5), fn x -> "\#{x} is too small" end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "3 is too small"}
  """
  @spec lift_predicate(
          term(),
          (term() -> boolean()),
          (term() -> left),
          TraceContext.opts_or_trace()
        ) ::
          t(left, term())
        when left: term()
  def lift_predicate(value, predicate, on_false, opts \\ []) do
    if predicate.(value) do
      Right.pure(value, opts)
    else
      Left.pure(on_false.(value), opts)
    end
  end

  @doc """
  Converts an `Either` value into the `Effect` monad.

  You can optionally pass telemetry trace metadata via `opts`.

  ## Examples

      iex> either = %Funx.Either.Right{right: 42}
      iex> result = Funx.Effect.lift_either(either)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}

      iex> either = %Funx.Either.Left{left: "error"}
      iex> result = Funx.Effect.lift_either(either)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "error"}
  """
  @spec lift_either(Either.t(left, right), TraceContext.opts_or_trace()) :: t(left, right)
        when left: term(), right: term()
  def lift_either(either, opts \\ [])

  def lift_either(%Either.Right{right: right_value}, opts) do
    Right.pure(right_value, opts)
  end

  def lift_either(%Either.Left{left: left_value}, opts) do
    Left.pure(left_value, opts)
  end

  @doc """
  Converts a `Maybe` value into the `Effect` monad.
  If the `Maybe` is `Just`, the value is wrapped in `Right`.
  If it is `Nothing`, the result of `on_none` is wrapped in `Left`.

  You can optionally provide trace metadata via `opts`.

  ## Examples

      iex> maybe = Funx.Maybe.just(42)
      iex> result = Funx.Effect.lift_maybe(maybe, fn -> "No value" end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}

      iex> maybe = Funx.Maybe.nothing()
      iex> result = Funx.Effect.lift_maybe(maybe, fn -> "No value" end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "No value"}
  """
  @spec lift_maybe(Maybe.t(right), (-> left), TraceContext.opts_or_trace()) :: t(left, right)
        when left: term(), right: term()
  def lift_maybe(maybe, on_none, opts \\ [])

  def lift_maybe(%Just{value: value}, _on_none, opts), do: Right.pure(value, opts)
  def lift_maybe(%Nothing{}, on_none, opts), do: Left.pure(on_none.(), opts)

  @doc """
  Transforms the `Left` branch of an `Effect`.

  If the `Effect` resolves to a `Left`, the provided function is applied to the error.
  If the `Effect` resolves to a `Right`, the value is returned unchanged.

  This function is useful when you want to rewrite or wrap errors without affecting successful computations.

  ## Examples

      iex> effect = Funx.Effect.left("error")
      iex> transformed = Funx.Effect.map_left(effect, fn e -> "wrapped: " <> e end)
      iex> Funx.Effect.run(transformed)
      %Funx.Either.Left{left: "wrapped: error"}

      iex> effect = Funx.Effect.pure(42)
      iex> transformed = Funx.Effect.map_left(effect, fn _ -> "should not be called" end)
      iex> Funx.Effect.run(transformed)
      %Funx.Either.Right{right: 42}
  """
  @spec map_left(t(error, value), (error -> new_error)) :: t(new_error, value)
        when error: term(), new_error: term(), value: term()
  def map_left(%Right{} = right, _func), do: right

  def map_left(%Left{effect: eff, trace: trace}, func) when is_function(func, 1) do
    promoted_trace = TraceContext.promote(trace, "map_left")

    %Left{
      trace: promoted_trace,
      effect: fn ->
        Task.async(fn ->
          case run(%Left{effect: eff, trace: trace}) do
            %Either.Left{left: error} -> %Either.Left{left: func.(error)}
            %Either.Right{} = right -> right
          end
        end)
      end
    }
  end

  @doc """
  Sequences a list of `Effect` computations, running each in order.

  If all effects resolve to `Right`, the result is a `Right` containing a list of values.
  If any effect resolves to `Left`, the sequencing stops early and that `Left` is returned.

  Each effect is executed with its own trace context, and telemetry spans are emitted for observability.

  ## Examples

      iex> effects = [Funx.Effect.right(1), Funx.Effect.right(2)]
      iex> result = Funx.Effect.sequence(effects)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: [1, 2]}

      iex> effects = [Funx.Effect.right(1), Funx.Effect.left("error")]
      iex> result = Funx.Effect.sequence(effects)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "error"}
  """
  @spec sequence([t(left, right)], TraceContext.opts_or_trace()) :: t(left, [right])
        when left: term(), right: term()
  def sequence(list, opts \\ []), do: traverse(list, fn x -> x end, opts)

  @doc """
  Traverses a list with a function that returns `Effect` computations,
  running each in sequence and collecting the `Right` results.

  If all effects resolve to `Right`, returns a single `Effect` with a list of results.
  If any effect resolves to `Left`, the traversal stops early and returns that `Left`.

  Each step preserves trace context and emits telemetry spans, including nested spans when bound.

  ## Examples

      iex> is_positive = fn num ->
      ...>   Funx.Effect.lift_predicate(num, fn x -> x > 0 end, fn x -> Integer.to_string(x) <> " is not positive" end)
      ...> end
      iex> result = Funx.Effect.traverse([1, 2, 3], fn num -> is_positive.(num) end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: [1, 2, 3]}
      iex> result = Funx.Effect.traverse([1, -2, 3], fn num -> is_positive.(num) end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "-2 is not positive"}
  """
  @spec traverse([input], (input -> t(left, right)), TraceContext.opts_or_trace()) ::
          t(left, [right])
        when input: term(), left: term(), right: term()

  def traverse(list, func), do: traverse(list, func, [])

  def traverse([], _func, opts), do: pure([], opts)

  def traverse(list, func, opts) when is_list(list) and is_function(func, 1) do
    traverse_trace = TraceContext.new(opts)

    list
    |> Enum.with_index()
    |> Enum.reduce_while(pure([], opts), fn {item, idx}, %Right{trace: acc_trace} = acc ->
      case {func.(item), acc} do
        {%Right{effect: eff1, trace: item_trace}, %Right{effect: eff2}} ->
          trace_with_name =
            TraceContext.default_span_name_if_empty(
              item_trace,
              "#{traverse_trace.span_name}[#{idx}]"
            )

          updated_trace = TraceContext.promote(trace_with_name, "traverse")

          {:cont,
           %Right{
             trace: updated_trace,
             effect: fn ->
               Task.async(fn ->
                 with %Either.Right{right: val} <-
                        run(%Right{effect: eff1, trace: trace_with_name}),
                      %Either.Right{right: acc_vals} <-
                        run(%Right{effect: eff2, trace: acc_trace}) do
                   %Either.Right{right: [val | acc_vals]}
                 end
               end)
             end
           }}

        {%Left{} = left, _} ->
          trace_with_name =
            TraceContext.default_span_name_if_empty(
              left.trace,
              "#{traverse_trace.span_name}[#{idx}]"
            )

          {:halt, %Left{left | trace: trace_with_name}}
      end
    end)
    |> map(&:lists.reverse/1)
  end

  @doc """
  Sequences a list of `Effect` computations, collecting all `Right` results
  or accumulating all `Left` errors if present.

  Unlike `sequence/1`, which stops at the first `Left`, this version continues processing
  all effects, returning a list of errors if any failures occur.

  Each effect emits its own telemetry span, and error contexts are preserved through tracing.

  ## Examples

      iex> effects = [
      ...>   Funx.Effect.right(1),
      ...>   Funx.Effect.left("Error 1"),
      ...>   Funx.Effect.left("Error 2")
      ...> ]
      iex> result = Funx.Effect.sequence_a(effects)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: ["Error 1", "Error 2"]}
  """

  @spec sequence_a([t(error, value)], TraceContext.opts_or_trace()) :: t([error], [value])
        when error: term(), value: term()
  def sequence_a(list, opts \\ []), do: traverse_a(list, fn x -> x end, opts)

  @doc """
  Traverses a list with a function that returns `Effect` values, combining results
  into a single `Effect`. Unlike `traverse/2`, this version accumulates all errors
  rather than stopping at the first `Left`.

  Each successful computation contributes to the final list of results.
  If any computations fail, all errors are collected and returned as a single `Left`.

  This function also manages telemetry trace context across all nested effects,
  ensuring that span relationships and trace IDs are preserved through the traversal.

  ## Examples

      iex> validate = fn n ->
      ...>   Funx.Effect.lift_predicate(n, fn x -> x > 0 end, fn x -> Integer.to_string(x) <> " is not positive" end)
      ...> end
      iex> result = Funx.Effect.traverse_a([1, -2, 3], validate)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: ["-2 is not positive"]}
      iex> result = Funx.Effect.traverse_a([1, 2, 3], validate)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: [1, 2, 3]}
  """
  @spec traverse_a([input], (input -> t(error, value)), TraceContext.opts_or_trace()) ::
          t([error], [value])
        when input: term(), error: term(), value: term()
  def traverse_a(list, func), do: traverse_a(list, func, [])

  def traverse_a([], _func, opts), do: right([], opts)

  def traverse_a(list, func, opts) when is_list(list) and is_function(func, 1) do
    traverse_trace = TraceContext.new(opts)

    list
    |> Enum.with_index()
    |> fold_l(right([], traverse_trace), fn {item, idx}, acc_result ->
      case {func.(item), acc_result} do
        {%Right{effect: eff1, trace: trace1}, %Right{effect: eff2, trace: trace2}} ->
          item_trace =
            TraceContext.default_span_name_if_empty(trace1, "#{traverse_trace.span_name}[#{idx}]")

          acc_trace =
            TraceContext.default_span_name_if_empty(trace2, "#{traverse_trace.span_name}[acc]")

          merged_trace =
            TraceContext.promote(TraceContext.merge(item_trace, acc_trace), "traverse_a")

          %Right{
            trace: merged_trace,
            effect: fn ->
              Task.async(fn ->
                with %Either.Right{right: val} <-
                       run(%Right{effect: eff1, trace: item_trace}),
                     %Either.Right{right: acc} <-
                       run(%Right{effect: eff2, trace: acc_trace}) do
                  %Either.Right{right: [val | acc]}
                end
              end)
            end
          }

        {%Left{effect: eff1, trace: trace1}, %Left{effect: eff2, trace: trace2}} ->
          item_trace =
            TraceContext.default_span_name_if_empty(trace1, "#{traverse_trace.span_name}[#{idx}]")

          acc_trace =
            TraceContext.default_span_name_if_empty(trace2, "#{traverse_trace.span_name}[acc]")

          merged_trace =
            TraceContext.promote(TraceContext.merge(item_trace, acc_trace), "traverse_a")

          %Left{
            trace: merged_trace,
            effect: fn ->
              Task.async(fn ->
                %Either.Left{
                  left:
                    as_list(run(%Left{effect: eff1, trace: item_trace}).left) ++
                      as_list(run(%Left{effect: eff2, trace: acc_trace}).left)
                }
              end)
            end
          }

        {%Right{}, %Left{effect: eff2, trace: trace2}} ->
          %Left{
            trace: trace2,
            effect: fn ->
              Task.async(fn -> run(%Left{effect: eff2, trace: trace2}) end)
            end
          }

        {%Left{effect: eff1, trace: trace1}, %Right{}} ->
          item_trace =
            TraceContext.default_span_name_if_empty(trace1, "#{traverse_trace.span_name}[#{idx}]")

          %Left{
            trace: item_trace,
            effect: fn ->
              Task.async(fn ->
                %Either.Left{
                  left: as_list(run(%Left{effect: eff1, trace: item_trace}).left)
                }
              end)
            end
          }
      end
    end)
    |> map(&:lists.reverse/1)
    |> map_left(&:lists.reverse/1)
  end

  defp as_list(val) when is_list(val), do: val
  defp as_list(val), do: [val]

  @doc """
  Validates a value using one or more validator functions, each returning an `Effect`.

  If all validators succeed (`Right`), the original value is returned in a `Right`.
  If any validator fails (`Left`), all errors are accumulated and returned as a single `Left`.

  This function also manages telemetry trace context across all nested validations,
  ensuring that span relationships and trace IDs are preserved throughout.

  Supports optional `opts` for span metadata (e.g. `:span_name`).

  ## Examples

      iex> validate_positive = fn x ->
      ...>   Funx.Effect.lift_predicate(x, fn n -> n > 0 end, fn n -> "Value " <> Integer.to_string(n) <> " must be positive" end)
      ...> end
      iex> validate_even = fn x ->
      ...>   Funx.Effect.lift_predicate(x, fn n -> rem(n, 2) == 0 end, fn n -> "Value " <> Integer.to_string(n) <> " must be even" end)
      ...> end
      iex> validators = [validate_positive, validate_even]
      iex> result = Funx.Effect.validate(4, validators)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 4}
      iex> result = Funx.Effect.validate(3, validators)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: ["Value 3 must be even"]}
      iex> result = Funx.Effect.validate(-3, validators)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: ["Value -3 must be positive", "Value -3 must be even"]}
  """

  @spec validate(
          value,
          (value -> t(error, any)) | [(value -> t(error, any))],
          TraceContext.opts_or_trace()
        ) ::
          t([error], value)
        when error: term(), value: term()

  def validate(value, validator, opts \\ [])

  def validate(value, validators, opts) when is_list(validators) do
    traverse_a(validators, fn v -> v.(value) end, opts)
    |> map(fn _ -> value end)
  end

  def validate(value, validator, opts) when is_function(validator, 1) do
    validate(value, [validator], opts)
  end

  @doc """
  Converts an Elixir `{:ok, value}` or `{:error, reason}` tuple into an `Effect`.

  Accepts an optional trace context for telemetry tracking.

  ## Examples

      iex> result = Funx.Effect.from_result({:ok, 42})
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}

      iex> result = Funx.Effect.from_result({:error, "error"})
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: "error"}
  """
  @spec from_result({:ok, right} | {:error, left}, TraceContext.opts_or_trace()) :: t(left, right)
        when left: term(), right: term()
  def from_result(result, opts \\ []) do
    case result do
      {:ok, value} -> Right.pure(value, opts)
      {:error, reason} -> Left.pure(reason, opts)
    end
  end

  @doc """
  Converts an `Effect` monad into an Elixir result tuple by executing the effect.

  You can optionally provide a `TraceContext` to control span naming, timeouts, or parent trace linking.

  ## Examples

      iex> effect = Funx.Effect.right(42)
      iex> Funx.Effect.to_result(effect)
      {:ok, 42}
      iex> trace = Funx.TraceContext.new(span_name: "custom span")
      iex> Funx.Effect.to_result(effect, trace)
      {:ok, 42}
      iex> error = Funx.Effect.left("fail")
      iex> Funx.Effect.to_result(error)
      {:error, "fail"}
  """
  @spec to_result(t(left, right), TraceContext.t() | nil) :: {:ok, right} | {:error, left}
        when left: term(), right: term()
  def to_result(effect, trace \\ nil) do
    case run(effect, trace) do
      %Either.Right{right: value} -> {:ok, value}
      %Either.Left{left: reason} -> {:error, reason}
    end
  end

  @doc """
  Wraps a function in an `Effect`, catching exceptions and wrapping them in a `Left`.

  You can optionally provide a `TraceContext` for telemetry and span propagation.

  ## Examples

      iex> result = Funx.Effect.from_try(fn -> 42 end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Right{right: 42}

      iex> result = Funx.Effect.from_try(fn -> raise "error" end)
      iex> Funx.Effect.run(result)
      %Funx.Either.Left{left: %RuntimeError{message: "error"}}
  """
  @spec from_try((-> right), TraceContext.opts_or_trace()) :: t(Exception.t(), right)
        when right: term()
  def from_try(func, opts_or_trace \\ []) do
    trace =
      case opts_or_trace do
        %TraceContext{} = trace -> trace
        opts when is_list(opts) -> TraceContext.new(opts)
      end

    try do
      result = func.()
      Right.pure(result, trace)
    rescue
      exception -> Left.pure(exception, trace)
    end
  end

  @doc """
  Unwraps a `Effect`, returning the value if it is a `Right`, or raising the exception if it is a `Left`.

  ## Examples

      iex> effect_result = Funx.Effect.right(42)
      iex> Funx.Effect.to_try!(effect_result)
      42

      iex> effect_error = Funx.Effect.left(%RuntimeError{message: "error"})
      iex> Funx.Effect.to_try!(effect_error)
      ** (RuntimeError) error
  """
  @spec to_try!(t(left, right)) :: right | no_return
        when left: term(), right: term()
  def to_try!(effect) do
    case run(effect) do
      %Either.Right{right: value} -> value
      %Either.Left{left: reason} -> raise reason
    end
  end
end
