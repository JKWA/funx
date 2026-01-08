defmodule Funx.Validator.GreaterThanTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.GreaterThan

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  alias Funx.Validator.GreaterThan

  describe "GreaterThan validator with numeric values" do
    test "passes when value is greater than threshold" do
      result =
        GreaterThan.validate(10,
          value: 5
        )

      assert result == Either.right(10)
    end

    test "fails when value is equal to threshold" do
      result =
        GreaterThan.validate(5,
          value: 5
        )

      assert Either.left?(result)
    end

    test "fails when value is less than threshold" do
      result =
        GreaterThan.validate(3,
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "GreaterThan validator with Maybe values" do
    test "passes for Nothing (not applicable)" do
      result =
        GreaterThan.validate(%Nothing{},
          value: 5
        )

      assert result == Either.right(%Nothing{})
    end

    test "passes for Just when inner value is greater than threshold" do
      result =
        GreaterThan.validate(%Just{value: 10},
          value: 5
        )

      assert result == Either.right(10)
    end

    test "fails for Just when inner value is not greater than threshold" do
      result =
        GreaterThan.validate(%Just{value: 5},
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "GreaterThan validator type errors" do
    test "fails for Just with non-number value" do
      result =
        GreaterThan.validate(%Just{value: "abc"},
          value: 5
        )

      assert Either.left?(result)
    end

    test "fails for non-number value" do
      result =
        GreaterThan.validate("abc",
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "GreaterThan validator with custom message" do
    test "uses custom message on failure" do
      result =
        GreaterThan.validate(3,
          value: 5,
          message: fn v -> "#{v} is too small" end
        )

      assert %Either.Left{left: %ValidationError{errors: ["3 is too small"]}} =
               result
    end
  end

  describe "GreaterThan validator argument validation" do
    test "raises when :value option is missing" do
      assert_raise KeyError, fn ->
        GreaterThan.validate(10, [])
      end
    end
  end

  describe "GreaterThan validator default arity" do
    test "raises when called without options" do
      assert_raise KeyError, fn ->
        GreaterThan.validate(10)
      end
    end
  end
end
