defmodule Funx.Monad.Effect do
  @moduledoc """
  The `Funx.Monad.Effect` module defines the `Effect` monad, which represents asynchronous computations
  that may succeed (`Right`) or fail (`Left`). Execution is deferred until explicitly run, making
  `Effect` useful for structuring lazy, asynchronous workflows.

  This module integrates tracing and telemetry, making it suitable for observability in concurrent
  Elixir systems. All effects carry a `Effect.Context`, which links operations and records spans
  when `run/2` is called.

  ## Constructors

    * `right/1` – Wraps a value in a successful `Right` effect.
    * `left/1` – Wraps a value in a failing `Left` effect.
    * `pure/1` – Alias for `right/1`.

  ## Execution

  * `run/2` – Executes the deferred effect and returns an `Either` result (`Right` or `Left`).

  You may pass `:task_supervisor` in the `opts` to run the effect under a specific `Task.Supervisor`. This supervises the top-level task, any internal tasks spawned within the effect function are not supervised.


  ## Sequencing

    * `sequence/1` – Runs a list of effects, stopping at the first `Left`.
    * `traverse/2` – Applies a function returning an `Effect` to each element of a list, sequencing results.
    * `sequence_a/2` – Runs a list of effects, collecting all `Left` errors instead of short-circuiting.
    * `traverse_a/3` – Like `traverse/2`, but accumulates errors across the list.

  ## Validation

    * `validate/2` – Validates a value using one or more effectful validators.

  ## Error Handling

    * `map_left/2` – Transforms a `Left` using a function, leaving `Right` values unchanged.
    * `flip_either/1` –  Inverts the success and failure branches of an `Effect`.

  ## Lifting

    * `lift_func/2` – Lifts a thunk that returns any value into an `Effect`, wrapping it in `Right`. If the thunk raises, the error is captured as a `Left(EffectError)`.
    * `lift_either/2` – Lifts a thunk that returns an `Either` into an `Effect`. Evaluation is deferred until the effect is run. Errors are also captured and wrapped in `Left(EffectError)`.
    * `lift_maybe/3` – Lifts a `Maybe` into an `Effect`, using a fallback error if the value is `Nothing`.
    * `lift_predicate/3` – Lifts a predicate check into an `Effect`. Returns `Right(value)` if the predicate passes; otherwise returns `Left(fallback)`.

  ## Reader Operations

    * `ask/0` – Returns the environment passed to `run/2` as a `Right`.
    * `asks/1` – Applies a function to the environment passed to `run/2`, wrapping the result in a `Right`.
    * `fail/0` – Returns the environment passed to `run/2` as a `Left`.
    * `fails/1` – Applies a function to the environment passed to `run/2`, wrapping the result in a `Left`.

  ## Elixir Interop

    * `from_result/2` – Converts a `{:ok, _}` or `{:error, _}` tuple into an `Effect`.
    * `to_result/1` – Converts an `Effect` to `{:ok, _}` or `{:error, _}`.
    * `from_try/2` – Wraps a function that may raise, returning Right on success, or Left if an exception is raised.
    * `to_try!/1` – Extracts the value from a `Right`, or raises an exception if `Left`.

  ## Protocols
    The Left and Right structs implement the following protocols:

     * Funx.Monad – Provides map/2, ap/2, and bind/2 for compositional workflows.

    Although protocol implementations are defined on Left and Right individually, the behavior
    is unified under the Effect abstraction.

    This module enables structured concurrency, error handling, and observability in
    asynchronous workflows.

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

      :telemetry.attach(
        "effect-run-handler",
        [:funx, :effect, :run, :stop],
        fn event, measurements, metadata, _config ->
          IO.inspect({event, measurements, metadata}, label: "Effect telemetry")
        end,
        nil
      )
  """

  import Funx.Appendable, only: [append: 2, coerce: 1]
  import Funx.Monad, only: [map: 2]

  alias Funx.Errors.EffectError
  alias Funx.Monad.{Effect, Either, Maybe}
  alias Effect.{Left, Right}
  alias Maybe.{Just, Nothing}

  @typedoc """
  Represents a deferred computation in the `Effect` monad that may either succeed (`Right`) or fail (`Left`).

  This type unifies `Effect.Right.t/1` and `Effect.Left.t/1` under a common interface, allowing code to
  operate over asynchronous effects regardless of success or failure outcome.

  Each variant carries a `context` for telemetry and a deferred `effect` function that takes an environment.
  """
  @type t(left, right) :: Effect.Left.t(left) | Effect.Right.t(right)

  @doc """
  Wraps a value in the `Right` variant of the `Effect` monad, representing a successful asynchronous computation.

  This is an alias for `pure/2`. You may optionally provide execution context, either as a keyword list or
  a `%Funx.Monad.Effect.Context{}` struct. The context is attached to the effect and propagated during execution.

  ## Examples

      iex> result = Funx.Monad.Effect.right(42)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 42}

      iex> context = Funx.Monad.Effect.Context.new(trace_id: "custom-id", span_name: "from right")
      iex> result = Funx.Monad.Effect.right(42, context)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 42}
  """
  @spec right(right, Effect.Context.opts_or_context()) :: t(term(), right) when right: term()
  def right(value, opts_or_context \\ []), do: Right.pure(value, opts_or_context)

  @doc """
  Alias for `right/2`.

  Wraps a value in the `Right` variant of the `Effect` monad, representing a successful asynchronous computation.

  Accepts either a keyword list of context options or a `Effect.Context` struct.

  ## Examples

      iex> result = Funx.Monad.Effect.pure(42)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 42}

      iex> context = Funx.Monad.Effect.Context.new(trace_id: "custom-id", span_name: "pure example")
      iex> result = Funx.Monad.Effect.pure(42, context)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 42}
  """
  @spec pure(right, Effect.Context.opts_or_context()) :: t(term(), right) when right: term()
  def pure(value, opts_or_context \\ []), do: right(value, opts_or_context)

  @doc """
  Wraps a value in the `Left` variant of the `Effect` monad, representing a failed asynchronous computation.

  Accepts either a keyword list of context options or a `Effect.Context` struct.

  ## Examples

      iex> result = Funx.Monad.Effect.left("error")
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: "error"}

      iex> context = Funx.Monad.Effect.Context.new(trace_id: "err-id", span_name: "failure")
      iex> result = Funx.Monad.Effect.left("error", context)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: "error"}
  """
  @spec left(left, Effect.Context.opts_or_context()) :: t(left, term()) when left: term()
  def left(value, opts_or_context \\ []), do: Left.pure(value, opts_or_context)

  @doc """
  Returns a `Funx.Monad.Effect.Right` that yields the environment passed to `Funx.Monad.Effect.run/2`.

  This is the Reader-style `ask`, used to access the full environment inside an effectful computation.

  ## Example

      iex> Funx.Monad.Effect.ask()
      ...> |> Funx.Monad.map(& &1[:region])
      ...> |> Funx.Monad.Effect.run(%{region: "us-west"})
      %Funx.Monad.Either.Right{right: "us-west"}
  """
  @spec ask :: Funx.Monad.Effect.Right.t()
  def ask, do: Right.ask()

  @doc """
  Returns a `Funx.Monad.Effect.Left` that fails with the entire environment passed to `Funx.Monad.Effect.run/2`.

  This is the Reader-style equivalent of `ask/0`, but marks the environment as a failure.
  Useful when the presence of certain runtime data should short-circuit execution.

  ## Example

      iex> Funx.Monad.Effect.fail()
      ...> |> Funx.Monad.Effect.run(%{error: :invalid_token})
      %Funx.Monad.Either.Left{left: %{error: :invalid_token}}
  """

  @spec fail :: Left.t()
  def fail, do: Left.ask()

  @doc """
  Returns a `Funx.Monad.Effect.Right` that applies the given function to the environment passed to `Funx.Monad.Effect.run/2`.

  This allows extracting a value from the environment and using it in an effectful computation,
  following the Reader pattern.

  ## Example

      iex> Funx.Monad.Effect.asks(fn env -> env[:user] end)
      ...> |> Funx.Monad.bind(fn user -> Funx.Monad.Effect.right(user) end)
      ...> |> Funx.Monad.Effect.run(%{user: "alice"})
      %Funx.Monad.Either.Right{right: "alice"}
  """
  @spec asks((term() -> term())) :: Right.t()
  def asks(f), do: Right.asks(f)

  @doc """
  Returns a `Funx.Monad.Effect.Left` that applies the given function to the environment passed to `Funx.Monad.Effect.run/2`.

  This is the failure-side equivalent of `asks/1`, used to produce an error effect based on runtime context.

  ## Example

      iex> Funx.Monad.Effect.fails(fn env -> {:missing_key, env} end)
      ...> |> Funx.Monad.Effect.run(%{input: nil})
      %Funx.Monad.Either.Left{left: {:missing_key, %{input: nil}}}
  """
  @spec fails((term() -> term())) :: Left.t()
  def fails(f), do: Left.asks(f)

  @doc """
  Runs the `Effect` and returns the result, awaiting the task if necessary.

  You may provide optional telemetry metadata using `opts`, such as `:span_name`
  to promote the current context with a new label.

  ## Options

    * `:span_name` – (optional) promotes the trace to a new span with the given name.

  ## Examples

      iex> result = Funx.Monad.Effect.right(42)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 42}

      iex> result = Funx.Monad.Effect.right(42, span_name: "initial")
      iex> Funx.Monad.Effect.run(result, span_name: "promoted")
      %Funx.Monad.Either.Right{right: 42}
  """

  @spec run(t(left, right)) :: Either.t(left, right)
        when left: term(), right: term()

  @spec run(t(left, right), map()) :: Either.t(left, right)
        when left: term(), right: term()

  @spec run(t(left, right), keyword()) :: Either.t(left, right)
        when left: term(), right: term()

  @spec run(t(left, right), map(), keyword()) :: Either.t(left, right)
        when left: term(), right: term()

  def run(effect) when is_struct(effect, Effect.Right) or is_struct(effect, Effect.Left),
    do: run(effect, %{}, [])

  def run(effect, env)
      when (is_struct(effect, Effect.Right) or is_struct(effect, Effect.Left)) and is_map(env),
      do: run(effect, env, [])

  def run(effect, opts)
      when (is_struct(effect, Funx.Monad.Effect.Right) or
              is_struct(effect, Funx.Monad.Effect.Left)) and
             is_list(opts) do
    env = Keyword.get(opts, :env, %{})
    run(effect, env, opts)
  end

  # NOTE: Coveralls is confused by the guard clause in the function head
  # coveralls-ignore-next-line
  def run(%{context: %Effect.Context{} = context} = effect, env, opts \\ [])
      when (is_struct(effect, Funx.Monad.Effect.Right) or
              is_struct(effect, Funx.Monad.Effect.Left)) and
             is_map(env) and
             is_list(opts) do
    context =
      opts
      |> maybe_promote_trace(context)
      |> Effect.Context.override(Keyword.delete(opts, :span_name))

    timeout = context.timeout || Funx.Config.timeout()
    span_name = context.span_name || Funx.Config.default_span_name()
    prefix = Funx.Config.telemetry_prefix() ++ [:effect, :run]

    if Funx.Config.telemetry_enabled?() do
      :telemetry.span(prefix, %{timeout: timeout, span_name: span_name}, fn ->
        result = execute_effect(effect, timeout, env, opts)
        {result, build_metadata(%{effect | context: context}, result, context)}
      end)
    else
      execute_effect(effect, timeout, env, opts)
    end
  end

  defp maybe_promote_trace(opts, context) do
    case Keyword.get(opts, :span_name) do
      nil -> context
      span_name -> Effect.Context.promote_trace(context, span_name)
    end
  end

  defp execute_effect(%Right{effect: eff}, timeout, env, opts) do
    case Keyword.fetch(opts, :task_supervisor) do
      {:ok, sup} ->
        Task.Supervisor.async_nolink(sup, fn ->
          task = eff.(env)
          Task.await(task, timeout)
        end)
        |> await(timeout)

      :error ->
        await(eff.(env), timeout)
    end
  end

  defp execute_effect(%Left{effect: eff}, timeout, env, opts) do
    case Keyword.fetch(opts, :task_supervisor) do
      {:ok, sup} ->
        Task.Supervisor.async_nolink(sup, fn ->
          task = eff.(env)
          Task.await(task, timeout)
        end)
        |> await(timeout)

      :error ->
        await(eff.(env), timeout)
    end
  end

  defp build_metadata(effect, result, %Effect.Context{} = context) do
    %{
      result: Funx.Config.summarizer().(result),
      effect_type: if(match?(%Either.Right{}, result), do: :right, else: :left),
      status: if(match?(%Either.Right{}, result), do: :ok, else: :error),
      span_name: context.span_name,
      trace_id: context.trace_id
    }
    |> maybe_put_parent_trace_id(effect)
  end

  defp maybe_put_parent_trace_id(meta, %{context: %Effect.Context{parent_trace_id: nil}}),
    do: meta

  defp maybe_put_parent_trace_id(meta, %{context: %Effect.Context{parent_trace_id: pid}}),
    do: Map.put(meta, :parent_trace_id, pid)

  @spec await(Task.t(), timeout()) :: Either.t(any(), any())
  def await(task, timeout \\ 5000) do
    try do
      case Task.yield(task, timeout) || Task.shutdown(task) do
        {:ok, %Either.Right{} = right} -> right
        {:ok, %Either.Left{} = left} -> left
        {:ok, other} -> Either.left(EffectError.new(:run, {:invalid_result, other}))
        nil -> Either.left(EffectError.new(:run, :timeout))
      end
    rescue
      error -> Either.left(EffectError.new(:run, error))
    end
  end

  @doc """
  Lifts a thunk into the `Effect` monad, wrapping its result in a `Right`.

  This function defers execution of the given zero-arity function (`thunk`) until the effect is run.
  The result is automatically wrapped as `Either.Right`.

  You may also pass a context or options (`opts`) to configure telemetry or span metadata.

  If the thunk raises an exception, it is caught and returned as a `Left` containing an `EffectError` tagged with `:lift`.

  ## Examples

      iex> result = Funx.Monad.Effect.lift_func(fn -> 42 end)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 42}

      iex> result = Funx.Monad.Effect.lift_func(fn -> raise "boom" end)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.EffectError{stage: :lift_func, reason: %RuntimeError{message: "boom"}}
      }
  """
  @spec lift_func((-> right), Effect.Context.opts_or_context()) :: t(left, right)
        when left: term(), right: term()
  def lift_func(thunk, opts \\ []) when is_function(thunk, 0) do
    %Right{
      effect: fn _env ->
        Task.async(fn ->
          try do
            Either.pure(thunk.())
          rescue
            error -> Either.left(EffectError.new(:lift_func, error))
          end
        end)
      end,
      context: Effect.Context.new(opts)
    }
  end

  @doc """
  Lifts a value into the `Effect` monad based on a predicate.
  If the predicate returns true, the value is wrapped in `Right`.
  Otherwise, the result of calling `on_false` with the value is wrapped in `Left`.

  Optional context metadata (e.g. `:span_name`, `:trace_id`) can be passed via `opts`.

  ## Examples

      iex> result = Funx.Monad.Effect.lift_predicate(10, &(&1 > 5), fn x -> "\#{x} is too small" end)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 10}

      iex> result = Funx.Monad.Effect.lift_predicate(3, &(&1 > 5), fn x -> "\#{x} is too small" end)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: "3 is too small"}
  """
  @spec lift_predicate(
          term(),
          (term() -> boolean()),
          (term() -> left),
          Effect.Context.opts_or_context()
        ) ::
          t(left, term())
        when left: term()
  def lift_predicate(value, predicate, on_false, opts \\ []) do
    if predicate.(value) do
      right(value, opts)
    else
      left(on_false.(value), opts)
    end
  end

  @doc """
  Lifts a thunk that returns an `Either` into the `Effect` monad.

  Instead of passing an `Either` value directly, you provide a zero-arity function (`thunk`) that returns one.
  This defers execution until the effect is run, allowing integration with tracing and composable pipelines.

  You may also pass a context or options (`opts`) to configure telemetry or span metadata.

  If the thunk raises an exception, it is caught and returned as a `Left` containing an `EffectError` tagged with `:lift`.

  ## Examples

      iex> result = Funx.Monad.Effect.lift_either(fn -> %Funx.Monad.Either.Right{right: 42} end)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 42}

      iex> result = Funx.Monad.Effect.lift_either(fn -> %Funx.Monad.Either.Left{left: "error"} end)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: "error"}
  """
  @spec lift_either((-> Either.t(left, right)), Effect.Context.opts_or_context()) ::
          t(left, right)
        when left: term(), right: term()
  def lift_either(thunk, opts \\ []) when is_function(thunk, 0) do
    %Right{
      effect: fn _env ->
        Task.async(fn ->
          try do
            case thunk.() do
              %Either.Right{} = right -> right
              %Either.Left{} = left -> left
            end
          rescue
            error -> Either.left(EffectError.new(:lift_either, error))
          end
        end)
      end,
      context: Effect.Context.new(opts)
    }
  end

  @doc """
  Converts a `Maybe` value into the `Effect` monad.
  If the `Maybe` is `Just`, the value is wrapped in `Right`.
  If it is `Nothing`, the result of `on_none` is wrapped in `Left`.

  You can optionally provide context metadata via `opts`.

  ## Examples

      iex> maybe = Funx.Monad.Maybe.just(42)
      iex> result = Funx.Monad.Effect.lift_maybe(maybe, fn -> "No value" end)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 42}

      iex> maybe = Funx.Monad.Maybe.nothing()
      iex> result = Funx.Monad.Effect.lift_maybe(maybe, fn -> "No value" end)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: "No value"}
  """
  @spec lift_maybe(Maybe.t(right), (-> left), Effect.Context.opts_or_context()) :: t(left, right)
        when left: term(), right: term()
  def lift_maybe(maybe, on_none, opts \\ [])

  def lift_maybe(%Just{value: value}, _on_none, opts), do: right(value, opts)
  def lift_maybe(%Nothing{}, on_none, opts), do: left(on_none.(), opts)

  @doc """
  Transforms the `Left` branch of an `Effect`.

  If the `Effect` resolves to a `Left`, the provided function is applied to the error.
  If the `Effect` resolves to a `Right`, the value is returned unchanged.

  This function is useful when you want to rewrite or wrap errors without affecting successful computations.

  ## Examples

      iex> effect = Funx.Monad.Effect.left("error")
      iex> transformed = Funx.Monad.Effect.map_left(effect, fn e -> "wrapped: " <> e end)
      iex> Funx.Monad.Effect.run(transformed)
      %Funx.Monad.Either.Left{left: "wrapped: error"}

      iex> effect = Funx.Monad.Effect.pure(42)
      iex> transformed = Funx.Monad.Effect.map_left(effect, fn _ -> "should not be called" end)
      iex> Funx.Monad.Effect.run(transformed)
      %Funx.Monad.Either.Right{right: 42}
  """
  @spec map_left(t(error, value), (error -> new_error)) :: t(new_error, value)
        when error: term(), new_error: term(), value: term()
  def map_left(%Right{} = right, _func), do: right

  def map_left(%Left{effect: eff, context: context}, func) when is_function(func, 1) do
    promoted_context = Effect.Context.promote_trace(context, "map_left")

    %Left{
      context: promoted_context,
      effect: fn env ->
        Task.async(fn ->
          case Effect.run(%Left{effect: eff, context: context}, env) do
            %Either.Left{left: error} ->
              %Either.Left{left: func.(error)}

            %Either.Right{} = right ->
              right
          end
        end)
      end
    }
  end

  @doc """
  Inverts the success and failure branches of an `Effect`.

  For a `Right`, this reverses the result: a successful value becomes a failure, and
  a failure becomes a success. For a `Left`, only failure is expected; if the `Left`
  produces a success, it is ignored.

  This is useful when you want to reverse the semantics of a computation—treating
  an expected error as success, or vice versa.

  ## Examples

      iex> effect = Funx.Monad.Effect.pure(42)
      iex> flipped = Funx.Monad.Effect.flip_either(effect)
      iex> Funx.Monad.Effect.run(flipped)
      %Funx.Monad.Either.Left{left: 42}
      iex> effect = Funx.Monad.Effect.left("fail")
      iex> flipped = Funx.Monad.Effect.flip_either(effect)
      iex> Funx.Monad.Effect.run(flipped)
      %Funx.Monad.Either.Right{right: "fail"}
  """

  @spec flip_either(t(error, value)) :: t(value, error)
        when error: term(), value: term()

  def flip_either(%Right{context: context} = right) do
    promoted_trace = Effect.Context.promote_trace(context, "flip_either")

    %Right{
      context: promoted_trace,
      effect: fn env ->
        Task.async(fn ->
          run(right, env)
          |> Either.flip()
        end)
      end
    }
  end

  def flip_either(%Left{context: context} = left) do
    promoted_trace = Effect.Context.promote_trace(context, "flip_either")

    %Right{
      context: promoted_trace,
      effect: fn env ->
        Task.async(fn ->
          run(left, env)
          |> Either.flip()
        end)
      end
    }
  end

  @doc """
  Sequences a list of `Effect` computations, running each in order.

  If all effects resolve to `Right`, the result is a `Right` containing a list of values.
  If any effect resolves to `Left`, the sequencing stops early and that `Left` is returned.

  Each effect is executed with its own context context, and telemetry spans are emitted for observability.

  ## Examples

      iex> effects = [Funx.Monad.Effect.right(1), Funx.Monad.Effect.right(2)]
      iex> result = Funx.Monad.Effect.sequence(effects)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: [1, 2]}

      iex> effects = [Funx.Monad.Effect.right(1), Funx.Monad.Effect.left("error")]
      iex> result = Funx.Monad.Effect.sequence(effects)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: "error"}
  """
  @spec sequence([t(left, right)], Effect.Context.opts_or_context()) :: t(left, [right])
        when left: term(), right: term()
  def sequence(list, opts \\ []), do: traverse(list, fn x -> x end, opts)

  @doc """
  Traverses a list with a function that returns `Effect` computations,
  running each in sequence and collecting the `Right` results.

  If all effects resolve to `Right`, returns a single `Effect` with a list of results.
  If any effect resolves to `Left`, the traversal stops early and returns that `Left`.

  Each step preserves context context and emits telemetry spans, including nested spans when bound.

  ## Examples

      iex> is_positive = fn num ->
      ...>   Funx.Monad.Effect.lift_predicate(num, fn x -> x > 0 end, fn x -> Integer.to_string(x) <> " is not positive" end)
      ...> end
      iex> result = Funx.Monad.Effect.traverse([1, 2, 3], fn num -> is_positive.(num) end)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: [1, 2, 3]}
      iex> result = Funx.Monad.Effect.traverse([1, -2, 3], fn num -> is_positive.(num) end)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: "-2 is not positive"}
  """
  @spec traverse([input], (input -> t(left, right)), Effect.Context.opts_or_context()) ::
          t(left, [right])
        when input: term(), left: term(), right: term()

  def traverse(list, func), do: traverse(list, func, [])

  def traverse([], _func, opts), do: pure([], opts)

  def traverse(list, func, opts) when is_list(list) and is_function(func, 1) do
    root_context = Effect.Context.new(opts)

    list
    |> Enum.with_index()
    |> Enum.reduce_while(pure([], root_context), fn {item, idx},
                                                    %Right{context: acc_ctx, effect: acc_eff} ->
      case func.(item) do
        %Right{context: item_ctx, effect: item_eff} ->
          span_name = "#{root_context.span_name}[#{idx}]"
          named_ctx = Effect.Context.default_span_name_if_empty(item_ctx, span_name)
          updated_ctx = Effect.Context.promote_trace(named_ctx, "traverse")

          {:cont,
           %Right{
             context: updated_ctx,
             effect: fn env ->
               Task.async(fn ->
                 with %Either.Right{right: val} <-
                        Effect.run(%Right{context: named_ctx, effect: item_eff}, env),
                      %Either.Right{right: acc_vals} <-
                        Effect.run(%Right{context: acc_ctx, effect: acc_eff}, env) do
                   Either.pure([val | acc_vals])
                 end
               end)
             end
           }}

        %Left{context: fail_ctx} = left ->
          span_name = "#{root_context.span_name}[#{idx}]"
          named_ctx = Effect.Context.default_span_name_if_empty(fail_ctx, span_name)
          {:halt, %Left{left | context: named_ctx}}
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
      ...>   Funx.Monad.Effect.right(1),
      ...>   Funx.Monad.Effect.left("Error 1"),
      ...>   Funx.Monad.Effect.left("Error 2")
      ...> ]
      iex> result = Funx.Monad.Effect.sequence_a(effects)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: ["Error 1", "Error 2"]}
  """

  @spec sequence_a([t(error, value)], Effect.Context.opts_or_context()) :: t([error], [value])
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
      ...>   Funx.Monad.Effect.lift_predicate(n, fn x -> x > 0 end, fn x -> Integer.to_string(x) <> " is not positive" end)
      ...> end
      iex> result = Funx.Monad.Effect.traverse_a([1, -2, 3], validate)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: ["-2 is not positive"]}
      iex> result = Funx.Monad.Effect.traverse_a([1, 2, 3], validate)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: [1, 2, 3]}
  """
  @spec traverse_a([input], (input -> t(error, value)), Effect.Context.opts_or_context()) ::
          t([error], [value])
        when input: term(), error: term(), value: term()
  def traverse_a(list, func), do: traverse_a(list, func, [])

  def traverse_a([], _func, opts), do: right([], opts)

  def traverse_a(list, func, opts) when is_list(list) and is_function(func, 1) do
    root_context = Effect.Context.new(opts)

    effects =
      list
      |> Enum.with_index()
      |> Enum.map(fn {item, idx} ->
        case func.(item) do
          %Right{effect: eff, context: ctx} ->
            span_ctx =
              Effect.Context.default_span_name_if_empty(ctx, "#{root_context.span_name}[#{idx}]")

            %Right{context: span_ctx, effect: eff}

          %Left{effect: eff, context: ctx} ->
            span_ctx =
              Effect.Context.default_span_name_if_empty(ctx, "#{root_context.span_name}[#{idx}]")

            %Left{context: span_ctx, effect: eff}
        end
      end)

    %Right{
      context: root_context,
      effect: fn env ->
        Task.async(fn ->
          tasks = Enum.map(effects, &spawn_effect/1)
          results = Enum.map(tasks, &collect_result/1)

          {oks, errs} =
            Enum.split_with(results, fn
              {:ok, _, _} -> true
              {:error, _, _} -> false
            end)

          if errs == [] do
            merged_ctx = merge_trace(root_context, Enum.map(oks, &elem(&1, 1)), "traverse_a")

            values =
              oks
              |> Enum.map(fn {:ok, _, val} -> val end)
              |> Enum.filter(& &1)

            wrap_right(values, merged_ctx)
            |> run(env)
          else
            merged_ctx = merge_trace(root_context, Enum.map(errs, &elem(&1, 1)), "traverse_a")

            errors =
              errs
              |> Enum.map(fn {:error, _, val} -> coerce(val) end)
              |> Enum.reduce(&append(&2, &1))

            wrap_left(errors, merged_ctx)
            |> run(env)
          end
        end)
      end
    }
  end

  defp spawn_effect(%Right{context: ctx, effect: eff}),
    do: {:right, ctx, Task.async(fn -> run(%Right{context: ctx, effect: eff}, %{}) end)}

  defp spawn_effect(%Left{context: ctx, effect: eff}),
    do: {:left, ctx, Task.async(fn -> run(%Left{context: ctx, effect: eff}, %{}) end)}

  defp collect_result({:right, ctx, task}) do
    case await(task) do
      %Either.Right{right: val} -> {:ok, ctx, val}
      %Either.Left{left: err} -> {:error, ctx, err}
    end
  end

  defp collect_result({:left, ctx, task}) do
    case await(task) do
      %Either.Left{left: err} -> {:error, ctx, err}
    end
  end

  defp wrap_right(values, ctx) do
    %Right{
      context: ctx,
      effect: fn _ -> Task.async(fn -> Either.pure(values) end) end
    }
  end

  defp wrap_left(errors, ctx) do
    %Left{
      context: ctx,
      effect: fn _ -> Task.async(fn -> Either.left(errors) end) end
    }
  end

  defp merge_trace(base, traces, label) do
    traces
    |> Enum.reduce(base, &Effect.Context.merge/2)
    |> Effect.Context.promote_trace(label)
  end

  @doc """
  Validates a value using one or more validator functions, each returning an `Effect`.

  If all validators succeed (`Right`), the original value is returned in a `Right`.
  If any validator fails (`Left`), all errors are accumulated and returned as a single `Left`.

  This function also manages telemetry trace context across all nested validations,
  ensuring that span relationships and trace IDs are preserved throughout.

  Supports optional `opts` for span metadata (e.g. `:span_name`).

  ## Examples

      iex> validate_positive = fn x ->
      ...>   Funx.Monad.Effect.lift_predicate(x, fn n -> n > 0 end, fn n -> "Value " <> Integer.to_string(n) <> " must be positive" end)
      ...> end
      iex> validate_even = fn x ->
      ...>   Funx.Monad.Effect.lift_predicate(x, fn n -> rem(n, 2) == 0 end, fn n -> "Value " <> Integer.to_string(n) <> " must be even" end)
      ...> end
      iex> validators = [validate_positive, validate_even]
      iex> result = Funx.Monad.Effect.validate(4, validators)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 4}
      iex> result = Funx.Monad.Effect.validate(3, validators)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: ["Value 3 must be even"]}
      iex> result = Funx.Monad.Effect.validate(-3, validators)
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: ["Value -3 must be positive", "Value -3 must be even"]}
  """

  @spec validate(
          value,
          (value -> t(error, any)) | [(value -> t(error, any))],
          Effect.Context.opts_or_context()
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

  Accepts an optional context context which includes telemetry tracking.

  ## Examples

      iex> result = Funx.Monad.Effect.from_result({:ok, 42})
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Right{right: 42}

      iex> result = Funx.Monad.Effect.from_result({:error, "error"})
      iex> Funx.Monad.Effect.run(result)
      %Funx.Monad.Either.Left{left: "error"}
  """
  @spec from_result({:ok, right} | {:error, left}, Effect.Context.opts_or_context()) ::
          t(left, right)
        when left: term(), right: term()
  def from_result(result, opts \\ []) do
    case result do
      {:ok, value} -> right(value, opts)
      {:error, reason} -> left(reason, opts)
    end
  end

  @doc """
  Converts an `Effect` into an Elixir `{:ok, _}` or `{:error, _}` tuple by running the effect.

  If the effect completes successfully (`Right`), the result is wrapped in `{:ok, value}`.
  If the effect fails (`Left`), the error is returned as `{:error, reason}`.

  This function also emits telemetry via `run/2` and supports optional context metadata through keyword options.

  ## Options

    * `:span_name` – sets a custom span name for tracing and telemetry.

  ## Examples

      iex> effect = Funx.Monad.Effect.right(42, span_name: "convert-ok")
      iex> Funx.Monad.Effect.to_result(effect, span_name: "to_result")
      {:ok, 42}

      iex> error = Funx.Monad.Effect.left("fail", span_name: "convert-error")
      iex> Funx.Monad.Effect.to_result(error, span_name: "to_result")
      {:error, "fail"}

  Telemetry will include the promoted span name (`"to_result -> convert-ok"`) and context metadata.

  """

  @spec to_result(t(left, right), keyword()) :: {:ok, right} | {:error, left}
        when left: term(), right: term()
  def to_result(effect, opts \\ []) do
    case run(effect, opts) do
      %Either.Right{right: value} -> {:ok, value}
      %Either.Left{left: reason} -> {:error, reason}
    end
  end

  @doc """
  Lifts a potentially exception-raising function into a Kleisli function for the `Effect` monad.

  This returns a function of type (`input -> Effect`) that applies the given function to a value.
  If the function raises, the error is captured and returned in a `Left`. You can optionally
  provide a context (or opts) for tracing and telemetry.

  ## Examples
      iex> safe_div = Funx.Monad.Effect.from_try(fn x -> 10 / x end)
      iex> effect = Funx.Monad.Effect.pure(2) |> Funx.Monad.bind(safe_div)
      iex> Funx.Monad.Effect.run(effect)
      %Funx.Monad.Either.Right{right: 5.0}
      iex> bad_div = Funx.Monad.Effect.pure(0) |> Funx.Monad.bind(safe_div)
      iex> Funx.Monad.Effect.run(bad_div)
      %Funx.Monad.Either.Left{left: %ArithmeticError{}}
  """
  @spec from_try((input -> right), Effect.Context.opts_or_context()) ::
          (input -> t(Exception.t(), right))
        when input: term(), right: term()

  def from_try(func, opts_or_context \\ []) when is_function(func, 1) do
    context =
      case opts_or_context do
        %Effect.Context{} = ctx -> ctx
        opts when is_list(opts) -> Effect.Context.new(opts)
      end

    fn value ->
      %Right{
        context: context,
        effect: fn _env ->
          Task.async(fn ->
            Either.from_try(fn -> func.(value) end)
          end)
        end
      }
    end
  end

  @doc """
  Executes an `Effect` and returns the result if it is a `Right`. If the result is a `Left`,
  this function raises the contained error.

  This is useful when you want to interoperate with code that expects regular exceptions,
  such as within test assertions or imperative pipelines.

  Runs the effect with full telemetry tracing.

  ## Examples

      iex> effect = Funx.Monad.Effect.right(42, span_name: "return")
      iex> Funx.Monad.Effect.to_try!(effect)
      42

      iex> error = Funx.Monad.Effect.left(%RuntimeError{message: "failure"}, span_name: "error")
      iex> Funx.Monad.Effect.to_try!(error)
      ** (RuntimeError) failure

  Telemetry will emit a `:stop` event with `:status` set to `:ok` or `:error`, depending on the outcome.
  """

  @spec to_try!(t(left, right), keyword()) :: right | no_return
        when left: term(), right: term()
  def to_try!(effect, opts \\ []) do
    effect
    |> run(opts)
    |> Either.to_try!()
  end
end
