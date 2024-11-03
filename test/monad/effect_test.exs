defmodule EffectTest do
  @moduledoc false

  use ExUnit.Case
  import Monex.Effect
  alias Monex.{Either, Maybe}

  import Monex.Monad, only: [ap: 2, bind: 2, map: 2]
  import Monex.Foldable, only: [fold_r: 3]

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
  end

  describe "lift_predicate/3" do
    test "returns Right when predicate returns true" do
      result =
        lift_predicate(10, fn x -> x > 5 end, fn -> "Value is too small" end)
        |> run()

      assert result == Either.right(10)
    end

    test "returns Left when predicate returns false" do
      result =
        lift_predicate(3, fn x -> x > 5 end, fn -> "Value is too small" end)
        |> run()

      assert result == Either.left("Value is too small")
    end
  end

  describe "lift_either/1" do
    test "wraps an Either.Right into a Effect.Right" do
      either = %Either.Right{value: 42}

      result =
        lift_either(either)
        |> run()

      assert result == Either.right(42)
    end

    test "wraps an Either.Left into a Effect.Left" do
      either = %Either.Left{value: "error"}

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
        lift_predicate(num, &(&1 > 0), fn -> "#{num} is not positive" end)
      end

      result =
        traverse([1, 2, 3], is_positive)
        |> run()

      assert result == Either.right([1, 2, 3])
    end

    test "traverse with a list containing an invalid value returns a Left" do
      is_positive = fn num ->
        lift_predicate(num, &(&1 > 0), fn -> "#{num} is not positive" end)
      end

      result =
        traverse([1, -2, 3], is_positive)
        |> run()

      assert result == Either.left("-2 is not positive")
    end

    test "traverse with an empty list returns a Right with an empty list" do
      is_positive = fn num ->
        lift_predicate(num, &(&1 > 0), fn -> "#{num} is not positive" end)
      end

      result =
        traverse([], is_positive)
        |> run()

      assert result == Either.right([])
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

      assert run(result) == %Either.Right{value: 42}
    end

    test "converts a raised exception into Effect.Left" do
      result = from_try(fn -> raise "error" end)

      assert run(result) == %Either.Left{value: %RuntimeError{message: "error"}}
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
