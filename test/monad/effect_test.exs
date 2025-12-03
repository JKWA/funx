defmodule EffectTest do
  @moduledoc false

  use Funx.TestCase, async: true

  doctest Funx.Monad.Effect
  doctest Funx.Monad.Effect.Left
  doctest Funx.Monad.Effect.Right

  import Funx.Monad, only: [ap: 2, bind: 2, map: 2]
  import Funx.Monad.Effect
  import Funx.Foldable, only: [fold_l: 3, fold_r: 3]
  import Funx.Summarizable, only: [summarize: 1]

  alias Funx.Errors.{EffectError, ValidationError}
  alias Funx.Monad.{Effect, Either, Maybe}

  setup [:with_telemetry_config]

  describe "right/1" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "wraps a value in a Right struct" do
      result =
        right(42, span_name: "right")
        |> run()

      assert result == %Either.Right{right: 42}

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _},
                      %{
                        result: telemetry_result,
                        span_name: "right"
                      }}

      assert telemetry_result == summarize(result)
    end

    test "runs effect using provided Task.Supervisor" do
      {:ok, sup} = Task.Supervisor.start_link()

      result =
        right(42, span_name: "supervised")
        |> run(%{}, task_supervisor: sup)

      assert result == %Either.Right{right: 42}

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _},
                      %{
                        result: telemetry_result,
                        span_name: "supervised"
                      }}

      assert telemetry_result == summarize(result)
    end
  end

  describe "pure/1" do
    test "wraps a value in a Right struct" do
      result = pure(42) |> run()
      assert result == %Either.Right{right: 42}
    end

    test "pure is an alias for right" do
      assert pure(42) |> run() == right(42) |> run()
    end

    test "run returns a Left with :timeout if the task takes too long" do
      context = Effect.Context.new(span_name: "timeout test", timeout: 50)

      effect = %Effect.Right{
        context: context,
        effect: fn _env ->
          Task.async(fn ->
            Process.sleep(10_000)
            %Either.Right{right: :late}
          end)
        end
      }

      result = run(effect)

      assert %Either.Left{left: %EffectError{stage: :run, reason: :timeout}} = result
    end
  end

  describe "pure/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    @tag :telemetry
    test "accepts a context struct and preserves it" do
      trace_id = "trace_id"
      span_name = "test span"

      context = Effect.Context.new(trace_id: trace_id, span_name: span_name)
      effect = pure(123, context)

      assert %Effect.Right{context: ^context} = effect

      result = effect |> run()

      assert result == Either.right(123)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _},
                      %{
                        result: telemetry_result,
                        trace_id: ^trace_id,
                        span_name: ^span_name
                      }}

      assert telemetry_result == summarize(result)
    end

    test "promotes an context" do
      trace_id = "trace_id"
      span_name = "test span"

      context = Effect.Context.new(trace_id: trace_id, span_name: span_name)
      effect = pure(123, context)

      assert %Effect.Right{context: ^context} = effect

      result = run(effect, span_name: "promoted")

      assert result == Either.right(123)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _},
                      %{
                        result: telemetry_result,
                        parent_trace_id: ^trace_id,
                        span_name: "promoted -> test span"
                      }}

      assert telemetry_result == summarize(result)
    end

    @tag :telemetry
    test "accepts a keyword list and builds a context from it" do
      trace_id = "trace_id"
      span_name = "test span"

      effect = pure(456, span_name: span_name, trace_id: trace_id)
      result = effect |> run()

      assert result == Either.right(456)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _},
                      %{result: telemetry_result, trace_id: ^trace_id, span_name: ^span_name}}

      assert telemetry_result == summarize(result)
    end

    @tag :telemetry
    test "run returns a Left if task is invalid" do
      context = Effect.Context.new(span_name: "invalid task")

      effect = %Effect.Right{
        context: context,
        effect: fn _env -> :not_a_task end
      }

      result = effect |> run()

      assert match?(
               %Either.Left{
                 left: %EffectError{
                   stage: :run,
                   reason: %FunctionClauseError{}
                 }
               },
               result
             )
    end

    @tag :telemetry
    test "run returns a Left if task returns non-Either" do
      context = Effect.Context.new(span_name: "invalid result")

      effect = %Effect.Right{
        context: context,
        effect: fn _env ->
          Task.async(fn -> :not_an_either end)
        end
      }

      result = effect |> run()

      assert result == %Either.Left{
               left: %EffectError{
                 stage: :run,
                 reason: {:invalid_result, :not_an_either}
               }
             }
    end

    @tag :telemetry
    test "left/2 wraps a value and emits telemetry" do
      trace_id = "trace_id"
      span_name = "test span"

      effect =
        left("error", span_name: span_name, trace_id: trace_id)

      result = effect |> run()

      assert result == %Either.Left{left: "error"}

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _},
                      %{result: telemetry_result, trace_id: ^trace_id, span_name: ^span_name}}

      assert telemetry_result == summarize(result)
    end

    test "left/2 runs with Task.Supervisor and emits telemetry" do
      {:ok, sup} = Task.Supervisor.start_link()

      trace_id = "trace_id"
      span_name = "supervised left"

      effect =
        left("error", span_name: span_name, trace_id: trace_id)

      result = run(effect, %{}, task_supervisor: sup)

      assert result == %Either.Left{left: "error"}

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _},
                      %{result: telemetry_result, trace_id: ^trace_id, span_name: ^span_name}}

      assert telemetry_result == summarize(result)
    end

    @tag :telemetry
    test "left/2 accepts a Effect.Context and preserves it" do
      context = Effect.Context.new(trace_id: "left-direct-id", span_name: "left span")
      effect = left("fail", context)

      result = effect |> run()

      assert result == %Either.Left{left: "fail"}

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _},
                      %{
                        result: telemetry_result,
                        trace_id: "left-direct-id",
                        span_name: "left span",
                        status: :error
                      }}

      assert telemetry_result == summarize(result)
    end
  end

  describe "Effect.Right.asks/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "reads a value from the environment" do
      effect =
        Effect.Right.asks(fn env -> env[:user_id] end)
        |> Effect.run(%{user_id: 42})

      assert effect == Either.right(42)
    end

    test "returns a Right-tagged effect regardless of env content" do
      effect =
        Effect.Right.asks(fn env -> Map.get(env, :missing_key, :default) end)
        |> Effect.run()

      assert effect == Either.right(:default)
    end

    test "allows chaining with bind to perform a dependent effect" do
      result =
        Effect.Right.asks(fn env -> env[:config] end)
        |> Funx.Monad.bind(fn config ->
          Effect.right("Configured for #{config}")
        end)
        |> Effect.run(%{config: "production"})

      assert result == Either.right("Configured for production")
    end

    test "does not raise if env is empty but function handles it" do
      effect =
        Effect.Right.asks(fn _env -> :ok end)
        |> Effect.run(%{})

      assert effect == Either.right(:ok)
    end

    test "propagates telemetry with span name when context is passed" do
      span = "reads-key"
      ctx = Effect.Context.new(span_name: span)

      Effect.Right.asks(fn env -> env[:x] end, ctx)
      |> Effect.run(%{x: 1})

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], _,
                      %{span_name: ^span, effect_type: :right, status: :ok}},
                     100
    end
  end

  describe "Effect.fails/1" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "constructs a Left from the runtime environment" do
      result =
        Effect.fails(fn env -> {:missing, env[:key]} end)
        |> Effect.run(%{key: :user_id})

      assert result == Either.left({:missing, :user_id})
    end

    test "returns a Left even when no env values are accessed" do
      result =
        Effect.fails(fn _ -> :static_failure end)
        |> Effect.run(%{})

      assert result == Either.left(:static_failure)
    end

    test "supports dynamic error construction from nested maps" do
      env = %{input: %{field: "bad"}}

      result =
        Effect.fails(fn env -> {:invalid_field, env.input.field} end)
        |> Effect.run(env)

      assert result == Either.left({:invalid_field, "bad"})
    end

    test "propagates telemetry with custom span name" do
      ctx = Effect.Context.new(span_name: "fail-example")

      Effect.Left.asks(fn env -> {:error, env} end, ctx)
      |> Effect.run(%{reason: :bad_data})

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], _,
                      %{span_name: "fail-example", effect_type: :left, status: :error}},
                     100
    end
  end

  describe "run/2 telemetry" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    @tag :telemetry
    test "emits telemetry span on Right effect" do
      result = Effect.right(42) |> run()

      assert result == Either.right(42)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{result: telemetry_result, effect_type: :right, status: :ok}},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    @tag :telemetry
    test "emits telemetry span with context id" do
      context = Effect.Context.new(trace_id: "trace_id", span_name: "test span")

      effect = Effect.right(42, context)
      result = effect |> run()

      assert result == Either.right(42)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        effect_type: :right,
                        span_name: "test span",
                        status: :ok,
                        trace_id: "trace_id"
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    @tag :telemetry
    test "emits telemetry with span_name and telemetry_id inputs" do
      trace_id = "trace_id"
      span_name = "test span"

      effect = Effect.right(42, trace_id: trace_id, span_name: span_name)
      result = effect |> run()

      assert result == Either.right(42)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        effect_type: :right,
                        status: :ok,
                        trace_id: ^trace_id,
                        span_name: ^span_name
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    @tag :telemetry
    test "emits telemetry with defaults" do
      effect = Effect.right(42)
      result = effect |> run()

      assert result == Either.right(42)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      meta},
                     100

      assert is_integer(duration) and duration > 0
      assert meta.effect_type == :right
      assert meta.status == :ok
      assert meta.result == {:either_right, {:integer, 42}}
      assert is_binary(meta.trace_id)
      assert meta.span_name == Funx.Config.default_span_name()
    end

    @tag :telemetry
    test "emits telemetry span on Left effect" do
      result = left("error") |> run()

      assert result == Either.left("error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{result: telemetry_result, effect_type: :left, status: :error}},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end
  end

  describe "check telemetry disabled" do
    setup do
      Application.put_env(:funx, :telemetry_enabled, false, persistent: true)
      on_exit(fn -> Application.delete_env(:funx, :telemetry_enabled) end)
    end

    test "still returns the Right result" do
      result = right(42) |> run()
      assert result == %Either.Right{right: 42}
    end
  end

  describe "ap/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    @tag :telemetry
    test "ap applies a function inside a Right monad to a value inside another Right monad" do
      func = right(fn x -> x * 2 end, span_name: "multiply")
      value = right(10, span_name: "value")

      result =
        func
        |> ap(value)
        |> run()

      assert result == Either.right(20)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "multiply",
                        trace_id: parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "ap -> multiply",
                        parent_trace_id: ^parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "value",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    @tag :telemetry
    test "ap returns Left if the function is inside a Left monad" do
      func = left("error", span_name: "error")
      value = right(10, span_name: "value")

      result =
        func
        |> ap(value)
        |> run()

      assert result == Either.left("error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "error",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    @tag :telemetry
    test "ap returns Left if the value is inside a Left monad" do
      func = right(fn x -> x * 2 end, span_name: "multiply")
      value = left("error", span_name: "value")

      result =
        func
        |> ap(value)
        |> run()

      assert result == Either.left("error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "ap -> value",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    @tag :telemetry
    test "ap wraps exceptions raised by the function in an EffectError Left" do
      func = right(fn _ -> raise "boom" end, span_name: "boom")
      value = right(42, span_name: "value")

      result =
        func
        |> ap(value)
        |> run()

      assert %Either.Left{
               left: %EffectError{
                 stage: :ap,
                 reason: %RuntimeError{message: "boom"}
               }
             } = result

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "value",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "boom",
                        trace_id: parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "ap -> boom",
                        parent_trace_id: ^parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    @tag :telemetry
    test "ap returns Left if the function effect resolves to a Left" do
      context = Effect.Context.new(span_name: "failure")

      func = %Effect.Right{
        context: context,
        effect: fn _env -> Task.async(fn -> Either.left("bad function") end) end
      }

      value = right(42)

      result =
        ap(func, value)
        |> run()

      assert result == Either.left("bad function")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "failure",
                        trace_id: parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "ap -> failure",
                        parent_trace_id: ^parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end
  end

  describe "bind/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "bind applies a function returning a Right monad to the value inside a Right monad" do
      result =
        right(10, span_name: "value")
        |> bind(fn value -> right(value + 5, span_name: "add_5") end)
        |> run()

      assert result == Either.right(15)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "add_5",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "value",
                        trace_id: parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "bind -> value",
                        parent_trace_id: ^parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "bind returns Left when the function returns Left" do
      result =
        right(10, span_name: "value")
        |> bind(fn _value -> left("error", span_name: "left_error") end)
        |> run()

      assert result == Either.left("error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "left_error",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "value",
                        trace_id: parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "bind -> value",
                        parent_trace_id: ^parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "bind does not apply the function for a Left monad" do
      result =
        left("error", span_name: "left_error")
        |> bind(fn _value -> right(42, span_name: "value") end)
        |> run()

      assert result == Either.left("error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "left_error",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "bind chains multiple Right monads together" do
      result =
        right(10, span_name: "first")
        |> bind(fn value -> right(value + 5, span_name: "second") end)
        |> bind(fn value -> right(value * 2, span_name: "third") end)
        |> run()

      assert result == Either.right(30)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "first",
                        effect_type: :right,
                        status: :ok,
                        trace_id: first_id
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "second",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "third",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "bind -> first",
                        parent_trace_id: ^first_id,
                        trace_id: second_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "bind -> bind -> first",
                        parent_trace_id: ^second_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "bind short-circuits when encountering a Left after a Right" do
      result =
        right(10, span_name: "first")
        |> bind(fn value -> right(value + 5, span_name: "second") end)
        |> bind(fn _value -> left("error occurred", span_name: "error_value") end)
        |> bind(fn _value -> right(42, span_name: "third") end)
        |> run()

      assert result == Either.left("error occurred")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "first",
                        effect_type: :right,
                        status: :ok,
                        trace_id: first_id
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "second",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "error_value",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "bind -> first",
                        parent_trace_id: ^first_id,
                        trace_id: second_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "bind -> bind -> first",
                        parent_trace_id: ^second_id,
                        trace_id: third_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "bind -> bind -> bind -> first",
                        parent_trace_id: ^third_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "bind preserves the first Left encountered in a chain of Lefts" do
      result =
        left("first error", span_name: "first")
        |> bind(fn _value -> left("second error", span_name: "second") end)
        |> bind(fn _value -> left("third error", span_name: "third") end)
        |> run()

      assert result == Either.left("first error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "first",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "bind catches and wraps exceptions in Left tagged with EffectError at :bind stage" do
      effect =
        right("trigger", span_name: "bind test")
        |> bind(fn _ -> raise "bind failure" end)

      result = run(effect)

      assert match?(
               %Either.Left{
                 left: %EffectError{
                   stage: :bind,
                   reason: %RuntimeError{message: "bind failure"}
                 }
               },
               result
             )

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "bind -> bind test",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end
  end

  describe "map/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "map applies a function to the value inside a Right monad" do
      result =
        right(10, span_name: "value")
        |> map(fn value -> value * 2 end)
        |> run()

      assert result == Either.right(20)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "value",
                        trace_id: parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "map -> value",
                        parent_trace_id: ^parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "map does not apply the function for a Left monad" do
      result =
        left("error", span_name: "value")
        |> map(fn _value -> raise "Should not be called" end)
        |> run()

      assert result == Either.left("error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "value",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "map returns a Left if the effect resolves to a Left error" do
      context = Effect.Context.new(span_name: "bomb")

      error_effect = %Effect.Right{
        context: context,
        effect: fn _env ->
          Task.async(fn -> %Either.Left{left: "error"} end)
        end
      }

      result =
        error_effect
        |> map(fn _value -> raise "Should not be called" end)
        |> run()

      assert result == %Either.Left{left: "error"}

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "bomb",
                        trace_id: parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "map -> bomb",
                        parent_trace_id: ^parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "map wraps exceptions raised by the function in a Left" do
      result =
        right(42, span_name: "value")
        |> map(fn _ -> raise "boom" end)
        |> run()

      assert match?(
               %Either.Left{
                 left: %EffectError{
                   stage: :map,
                   reason: %RuntimeError{message: "boom"}
                 }
               },
               result
             )

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "value",
                        trace_id: parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "map -> value",
                        parent_trace_id: ^parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end
  end

  describe "map_left/2 for Effect" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "transforms a Left value" do
      result =
        left("error", span_name: "value")
        |> map_left(fn e -> "wrapped: " <> e end)
        |> run()

      assert result == Either.left("wrapped: error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "value",
                        trace_id: parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "map_left -> value",
                        parent_trace_id: ^parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "leaves a Right value unchanged" do
      result =
        right(42, span_name: "value")
        |> map_left(fn _ -> "should not be called" end)
        |> run()

      assert result == Either.right(42)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "value",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "can transform complex Left values" do
      result =
        left(%{code: 400}, span_name: "value")
        |> map_left(fn err -> Map.put(err, :handled, true) end)
        |> run()

      assert result == Either.left(%{code: 400, handled: true})

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "value",
                        trace_id: parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        result: telemetry_result,
                        span_name: "map_left -> value",
                        parent_trace_id: ^parent_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "does not call the function for Right" do
      refute_receive {:called}

      result =
        right(:ok, span_name: "value")
        |> map_left(fn _ ->
          send(self(), {:called})
          :fail
        end)
        |> run()

      assert result == Either.right(:ok)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "value",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "map_left returns Right if effect unexpectedly resolves to Right" do
      context = Effect.Context.new(span_name: "recovery")

      effect = %Effect.Left{
        context: context,
        effect: fn _env ->
          Task.async(fn -> %Either.Right{right: :recovered} end)
        end
      }

      result =
        effect
        |> map_left(fn _ -> :should_not_be_called end)
        |> run()

      assert result == Either.right(:recovered)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "recovery",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end
  end

  describe "Effect.tap/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "returns the original Right value unchanged" do
      result =
        right(5, span_name: "value")
        |> Effect.tap(fn _x -> :ok end)
        |> run()

      assert result == Either.right(5)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "value",
                        trace_id: parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "tap -> value",
                        parent_trace_id: ^parent_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "returns the original Left value unchanged" do
      result =
        left("error", span_name: "value")
        |> Effect.tap(fn _x -> :ok end)
        |> run()

      assert result == Either.left("error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "value",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "executes tap on Right without changing value" do
      result =
        right(42, span_name: "value")
        |> Effect.tap(fn _x -> :side_effect end)
        |> run()

      assert result == Either.right(42)
    end

    test "tap does not affect Left values" do
      result =
        left("error", span_name: "value")
        |> Effect.tap(fn _x -> :side_effect end)
        |> run()

      assert result == Either.left("error")
    end

    test "works in a pipeline with multiple taps" do
      result =
        right(5, span_name: "initial")
        |> map(&(&1 * 2))
        |> Effect.tap(fn _x -> :tap1 end)
        |> map(&(&1 + 1))
        |> Effect.tap(fn _x -> :tap2 end)
        |> run()

      assert result == Either.right(11)
    end

    test "discards the return value of the side effect function" do
      result =
        right(5, span_name: "value")
        |> Effect.tap(fn _x ->
          # Return value should be ignored
          :this_should_be_discarded
        end)
        |> run()

      assert result == Either.right(5)
    end

    test "allows side effects like logging without changing the value" do
      result =
        right(%{user: "alice", age: 30}, span_name: "user")
        |> Effect.tap(fn _user ->
          # Simulate logging - actual side effect happens async
          :logged
        end)
        |> run()

      assert result == Either.right(%{user: "alice", age: 30})
    end

    test "tap with bind in pipeline" do
      result =
        right(5, span_name: "initial")
        |> Effect.tap(fn _x -> :before_bind end)
        |> bind(fn x -> right(x * 2, span_name: "doubled") end)
        |> Effect.tap(fn _x -> :after_bind end)
        |> run()

      assert result == Either.right(10)
    end

    test "tap returns Left if effect unexpectedly resolves to Left" do
      context = Effect.Context.new(span_name: "unexpected")

      effect = %Effect.Right{
        context: context,
        effect: fn _env ->
          Task.async(fn -> %Either.Left{left: :unexpected_error} end)
        end
      }

      result =
        effect
        |> Effect.tap(fn _ -> :should_not_be_called end)
        |> run()

      assert result == Either.left(:unexpected_error)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "unexpected",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end
  end

  describe "flip_either/1" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "flips Right to Left" do
      result = flip_either(right("oops", span_name: "value")) |> run()
      assert result == Either.left("oops")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "flip_either -> value",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "flips Left to Right" do
      result = flip_either(left("recovered")) |> run()
      assert result == Either.right("recovered")
    end

    test "double flip_either returns original" do
      input = right("stay")
      result = input |> flip_either() |> flip_either() |> run()
      assert result == run(input)
    end

    test "flips structured data from Right to Left" do
      result = flip_either(right(%{status: :fail})) |> run()
      assert result == Either.left(%{status: :fail})
    end

    test "flips structured data from Left to Right" do
      result = flip_either(left(%{status: :hold})) |> run()
      assert result == Either.right(%{status: :hold})
    end
  end

  describe "Effect.lift_func/1" do
    test "wraps return value in Right" do
      thunk = fn -> 42 end
      effect = Effect.lift_func(thunk)
      assert %Either.Right{right: 42} = Effect.run(effect)
    end

    test "wraps raised error in Left with EffectError" do
      thunk = fn -> raise "boom" end
      effect = Effect.lift_func(thunk)
      result = Effect.run(effect)

      assert %Either.Left{
               left: %EffectError{stage: :lift_func, reason: %RuntimeError{message: "boom"}}
             } = result
    end

    test "preserves exception struct in reason" do
      thunk = fn -> raise ArgumentError, "bad argument" end
      effect = Effect.lift_func(thunk)
      result = Effect.run(effect)

      assert %Either.Left{
               left: %EffectError{
                 stage: :lift_func,
                 reason: %ArgumentError{message: "bad argument"}
               }
             } = result
    end

    test "can lift a no-op function" do
      thunk = fn -> :ok end
      effect = Effect.lift_func(thunk)
      assert %Either.Right{right: :ok} = Effect.run(effect)
    end
  end

  describe "lift_predicate/3" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "returns Right when predicate returns true" do
      result =
        lift_predicate(
          10,
          fn x -> x > 5 end,
          fn x -> "Value #{x} is too small" end,
          span_name: "predicate"
        )
        |> run()

      assert result == Either.right(10)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "predicate",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "returns Left when predicate returns false" do
      result =
        lift_predicate(
          3,
          fn x -> x > 5 end,
          fn x -> "Value #{x} is too small" end,
          span_name: "predicate"
        )
        |> run()

      assert result == Either.left("Value 3 is too small")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "predicate",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end
  end

  describe "lift_either/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "wraps an Either.Right thunk into an Effect.Right" do
      result =
        lift_either(fn -> %Either.Right{right: 42} end, span_name: "lift")
        |> run()

      assert result == Either.right(42)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "lift",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "wraps an Either.Left thunk into an Effect.Left" do
      result =
        lift_either(fn -> %Either.Left{left: "error"} end, span_name: "lift")
        |> run()

      assert result == Either.left("error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "lift",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "wraps a raised error inside the thunk into an Effect.Left with EffectError" do
      result =
        lift_either(fn -> raise "boom" end, span_name: "lift")
        |> run()

      assert %Either.Left{
               left: %EffectError{stage: :lift_either, reason: %RuntimeError{message: "boom"}}
             } = result

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "lift",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end
  end

  describe "lift_maybe/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "wraps a Just value into a Effect.Right" do
      maybe = Maybe.just(42)

      result =
        lift_maybe(maybe, fn -> "No value" end, span_name: "lift")
        |> run()

      assert result == Either.right(42)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "lift",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "wraps a Nothing value into a Effect.Left" do
      maybe = Maybe.nothing()

      result =
        lift_maybe(maybe, fn -> "No value" end, span_name: "lift")
        |> run()

      assert result == Either.left("No value")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "lift",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end
  end

  describe "fold_r/3 with results of Effect" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "applies right function for a Right value returned by a task" do
      right_value = right(42, span_name: "fold")

      result =
        right_value
        |> run()
        |> fold_r(
          fn value -> "Right value is: #{value}" end,
          fn _error -> "This should not be called" end
        )

      assert result == "Right value is: 42"

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "fold",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == {:either_right, {:integer, 42}}
    end

    test "applies left function for a Left value returned by a task" do
      left_value = left("Something went wrong", span_name: "fold")

      result =
        left_value
        |> run()
        |> fold_r(
          fn _value -> "This should not be called" end,
          fn error -> "Error: #{error}" end
        )

      assert result == "Error: Something went wrong"

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "fold",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == {:either_left, {:string, "Something went wrong"}}
    end
  end

  describe "fold_l/3 with results of Effect" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "applies right function for a Right value returned by a task" do
      right_value = right(42, span_name: "fold")

      result =
        right_value
        |> run()
        |> fold_l(
          fn value -> "Right value is: #{value}" end,
          fn _error -> "This should not be called" end
        )

      assert result == "Right value is: 42"

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "fold",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == {:either_right, {:integer, 42}}
    end

    test "applies left function for a Left value returned by a task" do
      left_value = left("Something went wrong", span_name: "fold")

      result =
        left_value
        |> run()
        |> fold_l(
          fn _value -> "This should not be called" end,
          fn error -> "Error: #{error}" end
        )

      assert result == "Error: Something went wrong"

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        result: telemetry_result,
                        span_name: "fold",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == {:either_left, {:string, "Something went wrong"}}
    end
  end

  describe "sequence/1" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "sequence with all Right values returns a Right with a list" do
      tasks = [
        right(1, span_name: "first"),
        right(2, span_name: "second"),
        right(3, span_name: "third")
      ]

      result =
        sequence(tasks, span_name: "sequence")
        |> run()

      assert result == Either.right([1, 2, 3])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "sequence",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "first",
                        trace_id: first_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "second",
                        trace_id: second_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "third",
                        trace_id: third_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse -> first",
                        parent_trace_id: ^first_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse -> second",
                        parent_trace_id: ^second_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse -> third",
                        parent_trace_id: ^third_id,
                        trace_id: traverse_third_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "map -> traverse -> third",
                        parent_trace_id: ^traverse_third_id,
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "sequence with a Left value returns the first encountered Left" do
      tasks = [
        right(1, span_name: "first"),
        left("Error occurred", span_name: "second"),
        right(3, span_name: "third"),
        left("Second Error occurred", span_name: "fourth")
      ]

      result =
        sequence(tasks, Effect.Context.new(span_name: "sequence"))
        |> run()

      assert result == Either.left("Error occurred")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        span_name: "second",
                        effect_type: :left,
                        status: :error,
                        result: telemetry_result
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "sequence with multiple Left values returns the first encountered Left" do
      tasks = [
        left("First error", span_name: "first"),
        left("Second error", span_name: "second"),
        right(3, span_name: "third")
      ]

      result =
        sequence(tasks)
        |> run()

      assert result == Either.left("First error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        span_name: "first",
                        effect_type: :left,
                        status: :error,
                        result: telemetry_result
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "sequence with an empty list returns a Right with an empty list" do
      tasks = []

      result =
        sequence(tasks, span_name: "sequence")
        |> run()

      assert result == Either.right([])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        span_name: "sequence",
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end
  end

  describe "traverse/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "traverse with a list of valid values returns a Right with a list" do
      is_positive = fn num ->
        lift_predicate(num, &(&1 > 0), fn x -> "#{x} is not positive" end)
      end

      result =
        traverse([1, 2, 3], is_positive, span_name: "traverse")
        |> run()

      assert result == Either.right([1, 2, 3])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse[0]",
                        trace_id: first_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse[1]",
                        trace_id: second_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse[2]",
                        trace_id: third_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse -> traverse[0]",
                        parent_trace_id: ^first_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse -> traverse[1]",
                        parent_trace_id: ^second_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse -> traverse[2]",
                        parent_trace_id: ^third_id,
                        trace_id: traverse_third_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "map -> traverse -> traverse[2]",
                        parent_trace_id: ^traverse_third_id,
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "traverse with a list containing an invalid value returns a Left" do
      is_positive = fn num ->
        lift_predicate(num, &(&1 > 0), fn x -> "#{x} is not positive" end)
      end

      result =
        traverse([1, -2, 3], is_positive, span_name: "traverse_a")
        |> run()

      assert result == Either.left("-2 is not positive")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        span_name: "traverse_a[1]",
                        effect_type: :left,
                        status: :error,
                        result: telemetry_result
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "traverse with an empty list returns a Right with an empty list" do
      is_positive = fn num ->
        lift_predicate(num, &(&1 > 0), fn x -> "#{x} is not positive" end)
      end

      result =
        traverse([], is_positive, span_name: "traverse")
        |> run()

      assert result == Either.right([])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        span_name: "traverse",
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "traverse triggers `else` when accumulator resolves to Left inside with" do
      context = Effect.Context.new(span_name: "traverse-early-left")

      # Function returns a valid Right effect
      is_valid = fn n -> right(n) end

      # Initial accumulator resolving to Left
      broken_acc = %Effect.Right{
        context: context,
        effect: fn _env ->
          Task.async(fn -> Either.left(:broken_accumulator) end)
        end
      }

      result =
        Enum.reduce_while([:ok], broken_acc, fn item, %Effect.Right{context: acc_trace} = acc ->
          case {is_valid.(item), acc} do
            {%Effect.Right{effect: eff1, context: trace1}, %Effect.Right{effect: eff2}} ->
              combined_trace =
                Effect.Context.promote_trace(Effect.Context.merge(trace1, acc_trace), "reduce")

              {:cont,
               %Effect.Right{
                 context: combined_trace,
                 effect: fn env ->
                   Task.async(fn ->
                     with %Either.Right{right: val} <-
                            run(%Effect.Right{effect: eff1, context: trace1}, env),
                          %Either.Right{right: acc_vals} <-
                            run(%Effect.Right{effect: eff2, context: acc_trace}, env) do
                       %Either.Right{right: [val | acc_vals]}
                     else
                       %Either.Left{} = left -> left
                     end
                   end)
                 end
               }}

            {%Effect.Left{} = left, _} ->
              {:halt, left}
          end
        end)
        |> map(&Enum.reverse/1)
        |> run()

      assert result == Either.left(:broken_accumulator)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        span_name: "traverse-early-left",
                        effect_type: :left,
                        status: :error,
                        result: telemetry_result
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end
  end

  describe "sequence_a/1" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "all Right values return a Right with all values" do
      tasks = [
        right(1, span_name: "first"),
        right(2, span_name: "second"),
        right(3, span_name: "third")
      ]

      result =
        sequence_a(tasks, span_name: "sequence")
        |> run()

      assert result == Either.right([1, 2, 3])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "sequence",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "first",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "second",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "third",
                        trace_id: third_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse_a -> third",
                        parent_trace_id: ^third_id,
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "multiple Left values accumulate and return a Left with all errors" do
      tasks = [
        right(1, span_name: "first"),
        left("Error 1", span_name: "second"),
        left("Error 2", span_name: "third"),
        right(3, span_name: "fourth")
      ]

      result =
        sequence_a(tasks, span_name: "sequence")
        |> run()

      assert result == Either.left(["Error 1", "Error 2"])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "second",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "third",
                        trace_id: third_id,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse_a -> third",
                        parent_trace_id: ^third_id,
                        # trace_id: fourth_id,
                        effect_type: :left,
                        status: :error,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "Right and Left values accumulate errors and return Left with all errors" do
      tasks = [
        left("Error 1"),
        right(2),
        left("Error 2")
      ]

      result =
        sequence_a(tasks)
        |> run()

      assert result == Either.left(["Error 1", "Error 2"])
    end

    test "empty list returns a Right with an empty list" do
      tasks = []

      result =
        sequence_a(tasks)
        |> run()

      assert result == Either.right([])
    end
  end

  describe "traverse_a/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "empty returns a Right with empty list" do
      result = traverse_a([], &right/1, span_name: "traverse") |> run()
      assert result == Either.right([])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{
                        span_name: "traverse",
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert is_integer(duration) and duration > 0
      assert telemetry_result == summarize(result)
    end

    test "applies a function and accumulates Right results" do
      result = traverse_a([1, 2, 3], &right/1, span_name: "traverse") |> run()
      assert result == Either.right([1, 2, 3])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse[0]",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse[1]",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse[2]",
                        trace_id: third_id,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse_a -> traverse[2]",
                        parent_trace_id: ^third_id,
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "returns Left with all errors if function fails on multiple elements" do
      result =
        traverse_a(
          [1, 2, 3],
          fn x ->
            lift_predicate(x, &(&1 <= 1), fn v -> ["bad: #{v}"] end)
          end,
          span_name: "traverse"
        )
        |> run()

      assert result == Either.left(["bad: 2", "bad: 3"])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse[1]",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse[2]",
                        trace_id: trace_2,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse_a -> traverse[2]",
                        parent_trace_id: ^trace_2,
                        effect_type: :left,
                        status: :error,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "returns Left with one error if only one element fails" do
      result =
        traverse_a(
          [1, 2, 3],
          fn x ->
            lift_predicate(x, &(&1 <= 2), fn v -> ["bad: #{v}"] end)
          end
        )
        |> run()

      assert result == Either.left(["bad: 3"])
    end

    test "preserves earlier Left even if later elements are Right" do
      result =
        traverse_a(
          [1, 2, 3],
          fn
            1 -> left(["fail 1"])
            2 -> right("ok 2")
            3 -> right("ok 3")
          end
        )
        |> run()

      assert result == Either.left(["fail 1"])
    end

    test "does not nest error lists inside Left" do
      result =
        traverse_a(
          [2, 3],
          fn x -> left(["bad: #{x}"]) end
        )
        |> run()

      assert result == Either.left(["bad: 2", "bad: 3"])
    end

    test "Right-tagged effect returns Left result" do
      validator = fn _ ->
        %Effect.Right{
          context: Effect.Context.new(span_name: "test"),
          effect: fn _env -> Task.async(fn -> Either.left("forced failure") end) end
        }
      end

      result =
        validate(:any_value, [validator], span_name: "validate")
        |> run()

      assert result == Either.left(["forced failure"])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], _,
                      %{span_name: "test", effect_type: :left, status: :error}},
                     100
    end
  end

  describe "traverse_a/2 with ValidationError" do
    defp fail_if_odd_effect(x) do
      if rem(x, 2) == 0 do
        right(x)
      else
        left(ValidationError.new("not even: #{x}"))
      end
    end

    test "returns Right when all elements pass" do
      result = traverse_a([2, 4, 6], &fail_if_odd_effect/1, span_name: "traverse") |> run()
      assert result == Either.right([2, 4, 6])
    end

    test "returns a ValidationError when one element fails" do
      result = traverse_a([2, 3, 4], &fail_if_odd_effect/1, span_name: "traverse") |> run()

      assert result ==
               Either.left(%ValidationError{
                 errors: ["not even: 3"]
               })
    end

    test "returns a merged ValidationError when multiple elements fail" do
      result = traverse_a([1, 2, 3, 4, 5], &fail_if_odd_effect/1, span_name: "traverse") |> run()

      assert result ==
               Either.left(%ValidationError{
                 errors: ["not even: 1", "not even: 3", "not even: 5"]
               })
    end

    test "does not wrap ValidationError again if already wrapped" do
      result =
        traverse_a(
          [1, 2],
          fn
            1 -> left(ValidationError.new(["pre_wrapped 1"]))
            2 -> left(ValidationError.new("from 2"))
          end,
          span_name: "traverse"
        )
        |> run()

      assert result ==
               Either.left(%ValidationError{
                 errors: ["pre_wrapped 1", "from 2"]
               })
    end

    test "preserves error order from left to right" do
      result =
        traverse_a(
          [1, 2, 3],
          fn x -> left(ValidationError.new("fail: #{x}")) end,
          span_name: "traverse"
        )
        |> run()

      assert result ==
               Either.left(%ValidationError{
                 errors: ["fail: 1", "fail: 2", "fail: 3"]
               })
    end
  end

  describe "validate/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "all validators pass, returns Right with the original value" do
      validator_1 = fn value -> if value > 0, do: right(value), else: left("too small") end

      validator_2 = fn value ->
        if rem(value, 2) == 0, do: right(value), else: left("not even")
      end

      result =
        validate(4, [validator_1, validator_2], span_name: "validate")
        |> run()

      assert result == Either.right(4)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "validate",
                        effect_type: :right,
                        trace_id: trace_0,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "validate[0]",
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "validate[1]",
                        trace_id: trace_1,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "traverse_a -> validate[1]",
                        parent_trace_id: ^trace_1,
                        effect_type: :right,
                        status: :ok
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "map -> validate",
                        parent_trace_id: ^trace_0,
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "one validator fails, returns Left with the error" do
      validator_1 = fn value -> if value > 0, do: right(value), else: left("too small") end

      validator_2 = fn value ->
        if rem(value, 2) == 0, do: right(value), else: left("not even")
      end

      result =
        validate(3, [validator_1, validator_2], span_name: "validate")
        |> run()

      assert result == Either.left(["not even"])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "validate",
                        trace_id: trace_0,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "map -> validate",
                        parent_trace_id: ^trace_0,
                        effect_type: :left,
                        status: :error,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "multiple validators fail, returns Left with all errors" do
      validator_1 = fn value -> if value > 10, do: right(value), else: left("too small") end

      validator_2 = fn value ->
        if rem(value, 2) == 0, do: right(value), else: left("not even")
      end

      result =
        validate(3, [validator_1, validator_2], span_name: "validate")
        |> run()

      assert result == Either.left(["too small", "not even"])

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "validate",
                        trace_id: trace_0,
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "validate[0]",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "validate[1]",
                        effect_type: :left,
                        status: :error
                      }},
                     100

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "map -> validate",
                        parent_trace_id: ^trace_0,
                        effect_type: :left,
                        status: :error,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "single validator passes, returns Right with the original value" do
      validator = fn value -> if value > 0, do: right(value), else: left("too small") end

      result =
        validate(5, validator)
        |> run()

      assert result == Either.right(5)
    end

    test "single validator fails, returns Left with the error in a list" do
      validator = fn value -> if value > 10, do: right(value), else: left("too small") end

      result =
        validate(5, validator)
        |> run()

      assert result == Either.left(["too small"])
    end
  end

  describe "from_result/1" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "converts {:ok, value} to Effect.Right" do
      result = from_result({:ok, 42}, span_name: "result") |> run()
      assert result == Either.right(42)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "result",
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end

    test "converts {:error, reason} to Effect.Left" do
      result = from_result({:error, "error"}, span_name: "result") |> run()
      assert result == Either.left("error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "result",
                        effect_type: :left,
                        status: :error,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == summarize(result)
    end
  end

  describe "to_result/1" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "converts Effect.Right to {:ok, value}" do
      result = to_result(right(42, span_name: "value"), span_name: "result")
      assert result == {:ok, 42}

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "result -> value",
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == {:either_right, {:integer, 42}}
    end

    test "converts Effect.Left to {:error, reason}" do
      effect_error = left("error")
      assert to_result(effect_error) == {:error, "error"}
    end
  end

  describe "from_try/2" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "returns Right when function succeeds" do
      value = 2
      add_one = fn v -> v + 1 end
      effect_fn = from_try(add_one, span_name: "result")

      effect = effect_fn.(value)
      assert run(effect) == Either.right(3)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _},
                      %{
                        span_name: "result",
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == {:either_right, {:integer, 3}}
    end

    test "returns Left when function raises" do
      context = Effect.Context.new(trace_id: "context-from-try", span_name: "try block")

      value = "not a number"
      add_one = fn v -> v + 1 end
      effect_fn = from_try(add_one, context)

      effect = effect_fn.(value)
      result = run(effect)

      assert match?(%Either.Left{left: %ArithmeticError{}}, result)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _},
                      %{
                        trace_id: "context-from-try",
                        span_name: "try block",
                        effect_type: :left,
                        status: :error,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result ==
               {:either_left,
                {:map,
                 [
                   __exception__: {:atom, true},
                   __module__: {:atom, ArithmeticError},
                   message: {:string, "bad argument in arithmetic expression"}
                 ]}}
    end
  end

  describe "to_try!/1" do
    setup do
      capture_telemetry([:funx, :effect, :run, :stop], self())
      :ok
    end

    test "returns value from Effect.Right" do
      effect_result = right(42, span_name: "value")
      assert to_try!(effect_result, span_name: "result") == 42

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: _duration},
                      %{
                        span_name: "result -> value",
                        effect_type: :right,
                        status: :ok,
                        result: telemetry_result
                      }},
                     100

      assert telemetry_result == {:either_right, {:integer, 42}}
    end

    test "raises the reason from Effect.Left" do
      exception = %RuntimeError{message: "something went wrong"}
      effect_error = left(exception)

      assert_raise RuntimeError, "something went wrong", fn ->
        to_try!(effect_error)
      end
    end
  end
end
