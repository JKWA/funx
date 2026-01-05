defmodule Funx.Validator.LessThanTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.LessThan

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  alias Funx.Validator.LessThan

  describe "LessThan validator with numeric values" do
    test "passes when value is less than threshold" do
      result =
        LessThan.validate(3,
          value: 5
        )

      assert result == Either.right(3)
    end

    test "fails when value is equal to threshold" do
      result =
        LessThan.validate(5,
          value: 5
        )

      assert Either.left?(result)
    end

    test "fails when value is greater than threshold" do
      result =
        LessThan.validate(7,
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "LessThan validator with Maybe values" do
    test "passes for Nothing (not applicable)" do
      result =
        LessThan.validate(%Nothing{},
          value: 5
        )

      assert result == Either.right(%Nothing{})
    end

    test "passes for Just when inner value is less than threshold" do
      result =
        LessThan.validate(%Just{value: 3},
          value: 5
        )

      assert result == Either.right(3)
    end

    test "fails for Just when inner value is not less than threshold" do
      result =
        LessThan.validate(%Just{value: 5},
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "LessThan validator type errors" do
    test "fails for Just with non-number value" do
      result =
        LessThan.validate(%Just{value: "abc"},
          value: 5
        )

      assert Either.left?(result)
    end

    test "fails for non-number value" do
      result =
        LessThan.validate("abc",
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "LessThan validator with custom message" do
    test "uses custom message on failure" do
      result =
        LessThan.validate(7,
          value: 5,
          message: fn v -> "#{v} is too large" end
        )

      assert %Either.Left{left: %ValidationError{errors: ["7 is too large"]}} =
               result
    end
  end

  describe "LessThan validator argument validation" do
    test "raises when :value option is missing" do
      assert_raise KeyError, fn ->
        LessThan.validate(3, [])
      end
    end
  end
end
