defmodule Funx.Validator.LessThanOrEqualTest do
  use ExUnit.Case, async: true

  doctest Funx.Validator.LessThanOrEqual

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  alias Funx.Validator.LessThanOrEqual

  describe "LessThanOrEqual validator with numeric values" do
    test "passes when value is less than threshold" do
      result =
        LessThanOrEqual.validate(3,
          value: 5
        )

      assert result == Either.right(3)
    end

    test "passes when value is equal to threshold" do
      result =
        LessThanOrEqual.validate(5,
          value: 5
        )

      assert result == Either.right(5)
    end

    test "fails when value is greater than threshold" do
      result =
        LessThanOrEqual.validate(7,
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "LessThanOrEqual validator with Maybe values" do
    test "passes for Nothing (not applicable)" do
      result =
        LessThanOrEqual.validate(%Nothing{},
          value: 5
        )

      assert result == Either.right(%Nothing{})
    end

    test "passes for Just when inner value is equal to threshold" do
      result =
        LessThanOrEqual.validate(%Just{value: 5},
          value: 5
        )

      assert result == Either.right(5)
    end

    test "fails for Just when inner value is greater than threshold" do
      result =
        LessThanOrEqual.validate(%Just{value: 7},
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "LessThanOrEqual validator type errors" do
    test "fails for Just with non-number value" do
      result =
        LessThanOrEqual.validate(%Just{value: "abc"},
          value: 5
        )

      assert Either.left?(result)
    end

    test "fails for non-number value" do
      result =
        LessThanOrEqual.validate("abc",
          value: 5
        )

      assert Either.left?(result)
    end
  end

  describe "LessThanOrEqual validator with custom message" do
    test "uses custom message on failure" do
      result =
        LessThanOrEqual.validate(7,
          value: 5,
          message: fn v -> "#{v} is too large" end
        )

      assert %Either.Left{left: %ValidationError{errors: ["7 is too large"]}} =
               result
    end
  end

  describe "LessThanOrEqual validator argument validation" do
    test "raises when :value option is missing" do
      assert_raise KeyError, fn ->
        LessThanOrEqual.validate(3, [])
      end
    end
  end
end
