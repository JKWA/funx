defmodule EffectTest do
  @moduledoc false

  # use ExUnit.Case
  use Funx.TestCase, async: true

  doctest Funx.Effect
  doctest Funx.Effect.Left
  doctest Funx.Effect.Right

  import Funx.Effect
  import Funx.Monad, only: [ap: 2, bind: 2, map: 2]
  import Funx.Foldable, only: [fold_l: 3, fold_r: 3]

  alias Funx.Effect.{Left, Right}
  alias Funx.{Either, Maybe}

  setup [:with_telemetry_config]

  describe "right/1" do
    test "wraps a value in a Right struct" do
      result = right(42) |> run()
      assert result == %Either.Right{right: 42}
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
      effect = %Funx.Effect.Right{
        effect: fn ->
          Task.async(fn ->
            Process.sleep(10_000)
            Funx.Either.right(:late)
          end)
        end
      }

      result = run(effect, timeout: 50)
      assert result == Either.left(:timeout)
    end

    test "run returns a Left with {:exception, error} if task is invalid" do
      effect = %Funx.Effect.Right{
        effect: fn -> :not_a_task end
      }

      result = run(effect)

      assert match?(
               %Either.Left{
                 left: {:exception, %FunctionClauseError{function: :yield, module: Task}}
               },
               result
             )
    end

    test "run returns a Left with {:invalid_result, value} if task returns non-Either" do
      effect = %Funx.Effect.Right{
        effect: fn ->
          Task.async(fn -> :not_an_either end)
        end
      }

      result = run(effect)

      assert result == %Either.Left{left: {:invalid_result, :not_an_either}}
    end
  end

  describe "run/2 telemetry" do
    @tag :telemetry
    test "emits telemetry span on Right effect" do
      capture_telemetry([:funx, :effect, :run, :stop], self())

      result = Funx.Effect.right(42) |> run()

      assert result == Either.right(42)

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{result: summarized, effect_type: :right, status: :ok}},
                     100

      assert is_integer(duration) and duration > 0
      assert summarized == {:either_right, {:integer, 42}}
    end

    @tag :telemetry
    test "emits telemetry span on Left effect" do
      capture_telemetry([:funx, :effect, :run, :stop], self())

      result = Funx.Effect.left("error") |> run()

      assert result == Either.left("error")

      assert_receive {:telemetry_event, [:funx, :effect, :run, :stop], %{duration: duration},
                      %{result: summarized, effect_type: :left, status: :error}},
                     100

      assert is_integer(duration) and duration > 0
      assert summarized == {:either_left, {:string, "error"}}
    end
  end

  describe "ap/2" do
    test "ap applies a function inside a Right monad to a value inside another Right monad" do
      func = right(fn x -> x * 2 end)
      value = right(10)

      result =
        func
        |> ap(value)
        |> run()

      assert result == Either.right(20)
    end

    test "ap returns Left if the function is inside a Left monad" do
      func = left("error")
      value = right(10)

      result =
        func
        |> ap(value)
        |> run()

      assert result == Either.left("error")
    end

    test "ap returns Left if the value is inside a Left monad" do
      func = right(fn x -> x * 2 end)
      value = left("error")

      result =
        func
        |> ap(value)
        |> run()

      assert result == Either.left("error")
    end

    test "ap wraps exceptions raised by the function in a Left" do
      func = right(fn _ -> raise "boom" end)
      value = right(42)

      result =
        func
        |> ap(value)
        |> run()

      assert %Either.Left{left: {:ap_exception, %RuntimeError{message: "boom"}}} = result
    end

    test "ap returns Left if the function effect resolves to a Left" do
      func = %Funx.Effect.Right{
        effect: fn -> Task.async(fn -> Either.left("bad function") end) end
      }

      value = right(42)

      result =
        ap(func, value)
        |> run()

      assert result == Either.left("bad function")
    end
  end

  describe "bind/2" do
    test "bind applies a function returning a Right monad to the value inside a Right monad" do
      result =
        right(10)
        |> bind(fn value -> right(value + 5) end)
        |> run()

      assert result == Either.right(15)
    end

    test "bind returns Left when the function returns Left" do
      result =
        right(10)
        |> bind(fn _value -> left("error") end)
        |> run()

      assert result == Either.left("error")
    end

    test "bind does not apply the function for a Left monad" do
      result =
        left("error")
        |> bind(fn _value -> right(42) end)
        |> run()

      assert result == Either.left("error")
    end

    test "bind chains multiple Right monads together" do
      result =
        right(10)
        |> bind(fn value -> right(value + 5) end)
        |> bind(fn value -> right(value * 2) end)
        |> run()

      assert result == Either.right(30)
    end

    test "bind short-circuits when encountering a Left after a Right" do
      result =
        right(10)
        |> bind(fn value -> right(value + 5) end)
        |> bind(fn _value -> left("error occurred") end)
        |> bind(fn _value -> right(42) end)
        |> run()

      assert result == Either.left("error occurred")
    end

    test "bind preserves the first Left encountered in a chain of Lefts" do
      result =
        left("first error")
        |> bind(fn _value -> left("second error") end)
        |> bind(fn _value -> left("third error") end)
        |> run()

      assert result == Either.left("first error")
    end
  end

  describe "map/2" do
    test "map applies a function to the value inside a Right monad" do
      result =
        right(10)
        |> map(fn value -> value * 2 end)
        |> run()

      assert result == Either.right(20)
    end

    test "map does not apply the function for a Left monad" do
      result =
        left("error")
        |> map(fn _value -> raise "Should not be called" end)
        |> run()

      assert result == Either.left("error")
    end

    test "map returns a Left if the effect resolves to a Left error" do
      error_effect = %Funx.Effect.Right{
        effect: fn ->
          Task.async(fn -> %Either.Left{left: "error"} end)
        end
      }

      result =
        error_effect
        |> map(fn _value -> raise "Should not be called" end)
        |> run()

      assert result == %Either.Left{left: "error"}
    end

    test "map wraps exceptions raised by the function in a Left" do
      result =
        right(42)
        |> map(fn _ -> raise "boom" end)
        |> run()

      assert match?(%Either.Left{left: {:map_exception, %RuntimeError{message: "boom"}}}, result)
    end
  end

  describe "map_left/2 for Effect" do
    test "transforms a Left value" do
      result =
        Left.pure("error")
        |> map_left(fn e -> "wrapped: " <> e end)
        |> run()

      assert result == Either.left("wrapped: error")
    end

    test "leaves a Right value unchanged" do
      result =
        Right.pure(42)
        |> map_left(fn _ -> "should not be called" end)
        |> run()

      assert result == Either.right(42)
    end

    test "can transform complex Left values" do
      result =
        Left.pure(%{code: 400})
        |> map_left(fn err -> Map.put(err, :handled, true) end)
        |> run()

      assert result == Either.left(%{code: 400, handled: true})
    end

    test "does not call the function for Right" do
      refute_receive {:called}

      result =
        Right.pure(:ok)
        |> map_left(fn _ ->
          send(self(), {:called})
          :fail
        end)
        |> run()

      assert result == Either.right(:ok)
    end

    test "map_left returns Right if effect unexpectedly resolves to Right" do
      effect = %Funx.Effect.Left{
        effect: fn ->
          Task.async(fn -> %Funx.Either.Right{right: :recovered} end)
        end
      }

      result =
        effect
        |> map_left(fn _ -> :should_not_be_called end)
        |> run()

      assert result == Either.right(:recovered)
    end
  end

  describe "lift_predicate/3" do
    test "returns Right when predicate returns true" do
      result =
        lift_predicate(10, fn x -> x > 5 end, fn x -> "Value #{x} is too small" end)
        |> run()

      assert result == Either.right(10)
    end

    test "returns Left when predicate returns false" do
      result =
        lift_predicate(3, fn x -> x > 5 end, fn x -> "Value #{x} is too small" end)
        |> run()

      assert result == Either.left("Value 3 is too small")
    end
  end

  describe "lift_either/1" do
    test "wraps an Either.Right into a Effect.Right" do
      either = %Either.Right{right: 42}

      result =
        lift_either(either)
        |> run()

      assert result == Either.right(42)
    end

    test "wraps an Either.Left into a Effect.Left" do
      either = %Either.Left{left: "error"}

      result =
        lift_either(either)
        |> run()

      assert result == Either.left("error")
    end
  end

  describe "lift_maybe/2" do
    test "wraps a Just value into a Effect.Right" do
      maybe = Maybe.just(42)

      result =
        lift_maybe(maybe, fn -> "No value" end)
        |> run()

      assert result == Either.right(42)
    end

    test "wraps a Nothing value into a Effect.Left" do
      maybe = Maybe.nothing()

      result =
        lift_maybe(maybe, fn -> "No value" end)
        |> run()

      assert result == Either.left("No value")
    end
  end

  describe "fold_r/3 with results of Effect" do
    test "applies right function for a Right value returned by a task" do
      right_value = right(42)

      result =
        right_value
        |> run()
        |> fold_r(
          fn value -> "Right value is: #{value}" end,
          fn _error -> "This should not be called" end
        )

      assert result == "Right value is: 42"
    end

    test "applies left function for a Left value returned by a task" do
      left_value = left("Something went wrong")

      result =
        left_value
        |> run()
        |> fold_r(
          fn _value -> "This should not be called" end,
          fn error -> "Error: #{error}" end
        )

      assert result == "Error: Something went wrong"
    end
  end

  describe "fold_l/3 with results of Effect" do
    test "applies right function for a Right value returned by a task" do
      right_value = right(42)

      result =
        right_value
        |> run()
        |> fold_l(
          fn value -> "Right value is: #{value}" end,
          fn _error -> "This should not be called" end
        )

      assert result == "Right value is: 42"
    end

    test "applies left function for a Left value returned by a task" do
      left_value = left("Something went wrong")

      result =
        left_value
        |> run()
        |> fold_l(
          fn _value -> "This should not be called" end,
          fn error -> "Error: #{error}" end
        )

      assert result == "Error: Something went wrong"
    end
  end

  describe "sequence/1" do
    test "sequence with all Right values returns a Right with a list" do
      tasks = [
        right(1),
        right(2),
        right(3)
      ]

      result =
        sequence(tasks)
        |> run()

      assert result == Either.right([1, 2, 3])
    end

    test "sequence with a Left value returns the first encountered Left" do
      tasks = [
        right(1),
        left("Error occurred"),
        right(3),
        left("Second Error occurred")
      ]

      result =
        sequence(tasks)
        |> run()

      assert result == Either.left("Error occurred")
    end

    test "sequence with multiple Left values returns the first encountered Left" do
      tasks = [
        left("First error"),
        left("Second error"),
        right(3)
      ]

      result =
        sequence(tasks)
        |> run()

      assert result == Either.left("First error")
    end

    test "sequence with an empty list returns a Right with an empty list" do
      tasks = []

      result =
        sequence(tasks)
        |> run()

      assert result == Either.right([])
    end
  end

  describe "traverse/2" do
    test "traverse with a list of valid values returns a Right with a list" do
      is_positive = fn num ->
        lift_predicate(num, &(&1 > 0), fn x -> "#{x} is not positive" end)
      end

      result =
        traverse([1, 2, 3], is_positive)
        |> run()

      assert result == Either.right([1, 2, 3])
    end

    test "traverse with a list containing an invalid value returns a Left" do
      is_positive = fn num ->
        lift_predicate(num, &(&1 > 0), fn x -> "#{x} is not positive" end)
      end

      result =
        traverse([1, -2, 3], is_positive)
        |> run()

      assert result == Either.left("-2 is not positive")
    end

    test "traverse with an empty list returns a Right with an empty list" do
      is_positive = fn num ->
        lift_predicate(num, &(&1 > 0), fn x -> "#{x} is not positive" end)
      end

      result =
        traverse([], is_positive)
        |> run()

      assert result == Either.right([])
    end

    test "traverse triggers `else` when accumulator resolves to Left inside with" do
      # Function returns a valid Right effect
      is_valid = fn n -> right(n) end

      # We'll inject this as the initial accumulator, resolving to Left
      broken_acc = %Funx.Effect.Right{
        effect: fn ->
          Task.async(fn -> Either.left(:broken_accumulator) end)
        end
      }

      # Now run a single-item traverse where acc = broken_acc and func returns Right
      result =
        Enum.reduce_while([:ok], broken_acc, fn item, %Right{} = acc ->
          case {is_valid.(item), acc} do
            {%Right{effect: eff1}, %Right{effect: eff2}} ->
              {:cont,
               %Right{
                 effect: fn ->
                   Task.async(fn ->
                     with %Either.Right{right: val} <- run(%Right{effect: eff1}),
                          %Either.Right{right: acc_vals} <- run(%Right{effect: eff2}) do
                       %Either.Right{right: [val | acc_vals]}
                     else
                       %Either.Left{} = left -> left
                     end
                   end)
                 end
               }}

            {%Left{} = left, _} ->
              {:halt, left}
          end
        end)
        |> map(&Enum.reverse/1)
        |> run()

      assert result == Either.left(:broken_accumulator)
    end
  end

  describe "sequence_a/1" do
    test "all Right values return a Right with all values" do
      tasks = [
        right(1),
        right(2),
        right(3)
      ]

      result =
        sequence_a(tasks)
        |> run()

      assert result == Either.right([1, 2, 3])
    end

    test "multiple Left values accumulate and return a Left with all errors" do
      tasks = [
        right(1),
        left("Error 1"),
        left("Error 2"),
        right(3)
      ]

      result =
        sequence_a(tasks)
        |> run()

      assert result == Either.left(["Error 1", "Error 2"])
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
    test "empty returns a Right with empty list" do
      result = traverse_a([], &right/1) |> run()
      assert result == Either.right([])
    end

    test "applies a function and accumulates Right results" do
      result = traverse_a([1, 2, 3], &right/1) |> run()
      assert result == Either.right([1, 2, 3])
    end

    test "returns Left with all errors if function fails on multiple elements" do
      result =
        traverse_a(
          [1, 2, 3],
          fn x ->
            lift_predicate(x, &(&1 <= 1), fn v -> ["bad: #{v}"] end)
          end
        )
        |> run()

      assert result == Either.left(["bad: 2", "bad: 3"])
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
  end

  describe "validate/2" do
    test "all validators pass, returns Right with the original value" do
      validator_1 = fn value -> if value > 0, do: right(value), else: left("too small") end

      validator_2 = fn value ->
        if rem(value, 2) == 0, do: right(value), else: left("not even")
      end

      result =
        validate(4, [validator_1, validator_2])
        |> run()

      assert result == Either.right(4)
    end

    test "one validator fails, returns Left with the error" do
      validator_1 = fn value -> if value > 0, do: right(value), else: left("too small") end

      validator_2 = fn value ->
        if rem(value, 2) == 0, do: right(value), else: left("not even")
      end

      result =
        validate(3, [validator_1, validator_2])
        |> run()

      assert result == Either.left(["not even"])
    end

    test "multiple validators fail, returns Left with all errors" do
      validator_1 = fn value -> if value > 10, do: right(value), else: left("too small") end

      validator_2 = fn value ->
        if rem(value, 2) == 0, do: right(value), else: left("not even")
      end

      result =
        validate(3, [validator_1, validator_2])
        |> run()

      assert result == Either.left(["too small", "not even"])
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
    test "converts {:ok, value} to Effect.Right" do
      result = from_result({:ok, 42})
      assert run(result) == Either.right(42)
    end

    test "converts {:error, reason} to Effect.Left" do
      result = from_result({:error, "error"})
      assert run(result) == Either.left("error")
    end
  end

  describe "to_result/1" do
    test "converts Effect.Right to {:ok, value}" do
      effect_result = right(42)
      assert to_result(effect_result) == {:ok, 42}
    end

    test "converts Effect.Left to {:error, reason}" do
      effect_error = left("error")
      assert to_result(effect_error) == {:error, "error"}
    end
  end

  describe "from_try/1" do
    test "converts a successful function into Effect.Right" do
      result = from_try(fn -> 42 end)

      assert run(result) == %Either.Right{right: 42}
    end

    test "converts a raised exception into Effect.Left" do
      result = from_try(fn -> raise "error" end)

      assert run(result) == %Either.Left{left: %RuntimeError{message: "error"}}
    end
  end

  describe "to_try!/1" do
    test "returns value from Effect.Right" do
      effect_result = right(42)
      assert to_try!(effect_result) == 42
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
